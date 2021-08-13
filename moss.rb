#!/usr/bin/env ruby
require 'English'
require "pathname"
require "tempfile"
require "json"

# don't change these lines without changing the sed commands in Makefile
AGE='age'
AGE_KEYGEN='age-keygen'
GIT='git'

def xdg_data_home
  ENV.fetch("XDG_DATA_HOME", "#{ENV['HOME']}/.local/share")
end

class Moss
  MossError = Class.new(RuntimeError)
  attr_reader :root

  def initialize(root)
    @root = Pathname.new(root)
  end

  def encrypted?(filename)
    magic = "age-encryption.org/v1"
    File.read(filename, magic.length) == magic
  end

  # this works like backticks, but can be passed an array instead of a
  # string, thus avoiding shell quoting pitfalls
  private def capture_output(command)
    if command.respond_to?(:first) then command = command.map(&:to_s) end
    IO.popen(command, &:read)
  end

  def pubkey_for_identity(filename)
    pubkey =
      if encrypted?(filename)
        plaintext = capture_output([AGE, "-d", filename])
        IO.popen([AGE_KEYGEN, "-y", "-"], "r+") do |f|
          f.write(plaintext)
          f.close_write
          f.read
        end
      else
        capture_output([AGE_KEYGEN, "-y", filename.to_s])
      end
    if $CHILD_STATUS.exitstatus.zero?
      pubkey
    else
      raise MossError, "can't get public key from identity #{filename}"
    end
  end

  # This is the method that "moss init" calls, which could be better
  # named. "initialize" would be a good name if it weren't special to
  # Ruby
  def create(keyfile)
    keyfile.exist? or raise MossError, "Cannot read identity at #{keyfile}"
    recipient = pubkey_for_identity(keyfile)
    store.mkpath
    FileUtils.cp(keyfile, store.parent.join("identity"))
    File.open(store.join(".recipients"), "w") do |f|
      f.write recipient
    end
  end

  def store
    root.join("store")
  end

  def identity_file
    root.join("identity")
  end

  def git_managed?
    store.join(".git").exist?
  end

  # ascend the directory hierarchy looking for the filename,
  # stopping at the store directory. this method is badly named
  private def find_in_subtree(subtree, filename)
    pathname = subtree.join(filename)
    if pathname.readable?
      pathname
    elsif subtree.to_s > store.to_s
      find_in_subtree(subtree.parent, filename)
    end
  end

  private def recipients_for_secret(name)
    pathname = store.join("#{name}.age")
    find_in_subtree(pathname.parent, ".recipients") or
      raise MossError, "Can't find .recipients for #{name}"
  end

  def write_secret(name, content, overwrite: false)
    pathname = store.join("#{name}.age")
    if  pathname.exist? && !overwrite
      raise MossError,"#{pathname.to_s} exists, use --force to overwrite"
    end
    pathname.dirname.mkpath
    IO.popen([AGE,
              "-a", "--recipients-file", recipients_for_secret(name).to_s,
              "-o", pathname.to_s], "w") do |f|
      f.write(content)
    end
    if git_managed?
      Kernel.system(GIT, "add", pathname.relative_path_from(store).to_s,
                    {chdir: MOSS.store})
      Kernel.system(GIT, "commit", "-m", "new secret",
                    {chdir: MOSS.store})
    end
  end

  def read_secret(name)
    pathname = store.join("#{name}.age")
    File.exist?(pathname) or raise MossError, "Can't open non-existent file #{pathname}"
    capture_output([AGE,
                    "-i", identity_file,
                    "-d", pathname])
  end

  def remove_secret(name)
    pathname = store.join("#{name}.age")
    File.exist?(pathname) or raise MossError, "Can't remove non-existent file #{pathname}"
    pathname.delete
  end

  def secrets
    Dir[store.join("**/*.age")].map { |n|
      Pathname.new(n).relative_path_from(store).sub_ext("").to_s
    }
  end

  def config
    {
      store: store.to_s,
      identity_file: identity_file.to_s,
      git: git_managed?
    }
  end

  def git_operation(parameters)
    if git_managed? || parameters.first == "init"
      Kernel.system(GIT, *parameters, { chdir: store })
    else
      raise MossError, "not a git repo"
    end
  end
end

MOSS = Moss.new(ENV["MOSS_HOME"] || "#{xdg_data_home}/moss")

def random_alnum(length)
  bytes = File.open("/dev/urandom", "rb") do |random|
    random.read(length).unpack("C*").map { |c|
      c = c % 62
      if c < 26
        ("A".ord + c)
      elsif c < 52
        ("a".ord + (c - 26))
      else
        ("0".ord + (c - 52))
      end
    }
  end
  bytes.pack("C*")
end

class CLI
  class << self
    # This would be more robust with class instance variables instead
    # of class variables as used here, because different subclasses
    # will share this hash.

    @@commands = {}

    def command(command_name, docstring, &blk)
      define_method command_name, &blk
      @@commands[command_name] = { name: command_name, doc: docstring }
    end

    def link(ends)
      dest, src = ends.first
      @@commands[dest] = { name: @@commands[src][:name] }
    end
  end

  def parse_arguments(argv)
    name = argv.first.to_sym
    args = argv.drop(1)

    begin
      command = @@commands.fetch(name)
    rescue KeyError
      raise UsageError,"moss: unrecognised command. See \"moss help\""
    end

    method_signature = method(command[:name]).parameters

    return [name, []] if method_signature.empty?

    # The method we dispatch to expects either a varargs (splat)
    # array, or a hash in which every argument is named. So if there
    # is a method blah(peter:, paul:, mary:) and the user runs
    # `blah jones tall --mary=contrary`, first we look for
    # the named arguments (mary => contrary),  then we assign the remaining
    # parameters (peter => jones, paul => tall) from the argument array
    # in the order they appear in the method signature

    # (I've never used JCL, but I was once an Amiga programmer)

    flags = argv.reduce({}) {|m, flag|
      key, val= flag.match(/\A--(\w+)(?:=(.+))?/)&.captures
      key ?
        m.merge(key.to_sym => (val || :key_present)) :
        m
    }

    payload = method_signature.reduce({}) { |m, (type, name)|
      case type
      when :rest
        args
      when :keyreq
        args.first ? m.merge(name => args.shift) : m
      when :key
        m
      end
    }
    [command[:name],
     payload.respond_to?(:merge) ? flags.merge(payload) : payload]
  end

  def params_to_s(meth)
    meth.parameters.map { |(type, name)|
      case type
      when :req, :keyreq
        "<#{name}>"
      when :rest
        "<#{name}...>"
      when :key
        "[--#{name}]"
      end
    }.join(" ")
  end

  def describe_usage(method_name)
    param_string = params_to_s(method(method_name))
    "#{method_name} #{param_string}"
  end

  UsageError = Class.new(Moss::MossError)

  def dispatch(argv)
    name, payload = parse_arguments(argv)
    begin
      if payload.respond_to?(:keys)
        public_send(name,  **payload)
      else
        public_send(name,  *payload)
      end
    rescue ArgumentError
      raise UsageError, "usage: moss #{argv.first} #{params_to_s(method(name))}"
    end
  end

  def usage
    command_texts = @@commands.map { |name, command|
      if command[:doc]
        format "  %-40s - %s",
               describe_usage(name),
               command[:doc]
      else
        nil
      end
    }.compact

    usage_header + command_texts.join("\n")
  end
end

def cli
  cli = CLI.new
  class << cli
    def usage_header
      "Store and retrieve encrypted secrets\n\n" +
        "Usage: moss [command] [parameters]...\n\n"
    end
    command :generate, "generate a random secret" do |filename:, length:, force: false|
      secret = random_alnum(length.to_i)
      print secret
      MOSS.write_secret(filename, secret, overwrite: force)
    end

    command :add, "add a secret to the store (reads from standard input)" do |filename:, force: false|
      secret = $stdin.read
      MOSS.write_secret(filename, secret, overwrite: force)
    end
    link :insert => :add

    command :show, "display a secret" do |file:|
      $stdout.write(MOSS.read_secret(file))
    end
    link :cat => :show

    command :search, "search secrets with names matching term" do |*term|
      files = MOSS.secrets.filter { |f|
        f.match(Regexp.new(term.join(" ")))
      }
      files.each do |n|
        puts n
      end
    end
    link :list => :search

    command :edit, "edit a secret" do |file:|
      content = MOSS.read_secret(file)
      Tempfile.create(file.gsub(/\W/, "")) do |f|
        f.write(content)
        f.flush
        if Kernel.system(ENV["EDITOR"], f.path)
          f.rewind
          secret = f.read
          MOSS.write_secret(file, secret, overwrite: true)
        else
          raise MossError, $CHILD_STATUS.to_s
        end
      end
    end

    command :config, "show configuration" do
      puts JSON.generate(MOSS.config)
    end

    command :init, "create new moss repository" do |keyfile:|
      MOSS.create(Pathname.new(keyfile))
    end

    command :rm, "remove a secret" do |secret:|
      MOSS.remove_secret(secret)
    end

    command :git, "perform git operation in store" do |* git_command|
      MOSS.git_operation(git_command)
    end

    command :help, "display this help text" do
      puts usage
    end
  end
  cli
end


if $PROGRAM_NAME == __FILE__
  begin
    File.umask(0o77)
    cli.dispatch(ARGV)
  rescue Moss::MossError => e
    warn e.message
    exit 1
  end
end
