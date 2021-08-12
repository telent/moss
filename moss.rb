#!/usr/bin/env ruby
require 'pathname'
require 'tempfile'
require 'json'

File.umask(077)

# don't change these lines without changing the sed commands in Makefile
AGE='age'
AGE_KEYGEN='age-keygen'
GIT='git'

def xdg_data_home
  ENV.fetch("XDG_DATA_HOME", "#{ENV['HOME']}/.local/share")
end

class Moss
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
    IO.popen(command) {|f|
      f.read
    }
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
    if $?.exitstatus.zero?
      pubkey
    else
      raise "can't get public key from identity #{filename}"
    end
  end

  # This is the method that "moss init" calls, which could be better
  # named. "initialize" would be a good name if it weren't special to
  # Ruby
  def create(keyfile)
    keyfile.exist? or raise "Cannot read identity at #{keyfile}"
    recipient = pubkey_for_identity(keyfile)
    store.mkpath
    FileUtils.cp(keyfile,  store.parent.join("identity"))
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
    case
    when pathname.readable?
      pathname
    when subtree.to_s >  store.to_s
      find_in_subtree(subtree.parent, filename)
    else
      nil
    end
  end

  private def recipients_for_secret(name)
    pathname = store.join("#{name}.age")
    find_in_subtree(pathname.parent, ".recipients") or
      raise "Can't find .recipients for #{name}"
  end

  def write_secret(name, content)
    pathname = store.join("#{name}.age")
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
    File.exist?(pathname) or raise "Can't open non-existent file #{pathname}"
    capture_output([AGE,
                    "-i", identity_file,
                    "-d", pathname])
  end

  def secrets
    Dir[store.join('**/*.age')].map {|n|
      Pathname.new(n).relative_path_from(store).sub_ext('').to_s
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
    if (git_managed? || parameters.first == 'init')
      Kernel.system(GIT, *parameters, {chdir: store})
    else
      raise "not a git repo"
    end
  end
end


MOSS = Moss.new(ENV['MOSS_HOME'] || "#{xdg_data_home}/moss")

def random_alnum(length)
  bytes = File.open("/dev/urandom", "rb") do |random|
    random.read(length).unpack("C*").map {|c|
      c = c % 62
      case
      when c < 26
        ('A'.ord + c)
      when c < 52
        ('a'.ord + (c-26))
      else
        ('0'.ord + (c-52))
      end
    }
  end
  bytes.pack("C*")
end

class CLI
  class << self
    @@commands = {}
    def command(command_name, docstring, &blk)
      define_method command_name, &blk
      @@commands[command_name] = { name: command_name, doc: docstring }
    end
    def link(ends)
      dest, src = ends.first
      @@commands[dest] = { alias: src }
    end
  end

  def parse_arguments(argv)
    name = argv.first.to_sym
    args = argv.drop(1)
    raise NoMethodError unless @@commands.key?(name)
    command = @@commands[name]
    if dst = command[:alias]
      command = @@commands[dst]
    end
    arg_signature = method(command[:name]).parameters

    return [ name, [] ] if arg_signature.empty?

    flags = argv.reduce({}) {|m, flag|
      key, val= flag.match(/\A--(\w+)(?:=(.+))?/)&.captures
      key ?
        m.merge(key.to_sym => val ? val : :key_present) :
        m
    }

    payload = arg_signature.reduce({}) { |m, (type, name)|
      case type
      when :rest
        args
      when :keyreq
        args.first ? m.merge(name => args.shift) : m
      when :key
        m
      end
    }
    [ command[:name],
      payload.respond_to?(:merge) ? flags.merge(payload) : payload ]
  end

  def params_to_s(meth)
    meth.parameters.map {|(type, name)|
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

  UsageError = Class.new(RuntimeError)

  def dispatch(argv)
    name, payload = parse_arguments(argv)
    begin
      if payload.respond_to?(:keys)
        self.public_send(name,  **payload)
      else
        self.public_send(name,  *payload)
      end
    rescue ArgumentError => e
      raise UsageError, "usage: moss #{describe_usage(name)}"
    end
  end

  def usage
    command_texts = @@commands.map { |name, command|
      if command[:name]
        sprintf "  %-40s - %s",
                describe_usage(name),
                command[:doc]
      else
        ""
      end
    }

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
    command :generate, "generate a random secret" do |filename:, length:|
      secret = random_alnum(length.to_i)
      print secret
      MOSS.write_secret(filename, secret)
    end

    command :add, "add a secret to the store" do |filename:, force: false|
      secret = STDIN.read
      MOSS.write_secret(filename, secret)
    end
    link :insert => :add

    command :show, "display a secret" do |file:|
      STDOUT.write(MOSS.read_secret(file))
    end
    link :cat => :show

    command :search, "search secrets with names matching term" do |*term|
      files = MOSS.secrets.filter {|f|
        f.match(Regexp.new(term.join(" ")))
      }
      files.each do |n|
        puts n
      end
    end
    link :list => :search

    command :edit, "edit a secret" do |file:|
      content = MOSS.read_secret(file)
      Tempfile.create(file.gsub(/[\W]/,"")) do |f|
        f.write(content)
        f.flush
        if Kernel.system(ENV['EDITOR'], f.path)
          f.rewind
          secret = f.read
          MOSS.write_secret(file, secret)
        else
          raise "#{$?}"
        end
      end
    end

    command :config, "show configuration" do
      puts JSON.generate(MOSS.config)
    end

    command :init, "create new moss repository" do |keyfile:|
      MOSS.create(Pathname.new(keyfile))
    end

    command :git, "perform git operation in store" do |* git_command|
      MOSS.git_operation(git_command)
    end

    command :help, "display this help text" do
      puts self.usage
    end
  end
  cli
end

if $0==__FILE__
  # running as a script
  begin
    File.umask(077)
    cli.dispatch(ARGV)
  rescue StandardError => e
    warn e.message
    exit 1
  end
end
