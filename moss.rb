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
    File.exist?(pathname) or raise "Can't open #{pathname}: $!"
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
    raise "not a git repo" unless git_managed?
    Kernel.system(GIT, *parameters, {chdir: store})
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


action, *parameters = ARGV
case action
when 'generate'
  file , len = parameters
  secret = random_alnum(len.to_i)
  print secret
  MOSS.write_secret(file, secret)
when 'insert','add'
  file, = parameters
  secret = STDIN.read
  MOSS.write_secret(file, secret)
when 'cat','show'
  file, = parameters
  STDOUT.write(MOSS.read_secret(file))
when 'edit'
  file, = parameters
  content = MOSS.read_secret(file)
  Tempfile.create(file.gsub(/[\W]/,"")) do |f|
    f.write(content)
    f.flush
    if Kernel.system(ENV['EDITOR'], f.path)
      f.rewind
      secret = f.read
      MOSS.write_secret(file, secret)
    else
      raise "#{$!}"
    end
  end
when 'search','list'
  term = parameters.join(" ")
  files = MOSS.secrets.filter {|f|
    f.match(Regexp.new(term))
  }
  files.each do |n|
    puts n
  end
when 'config'
  puts JSON.generate(MOSS.config)
when 'init'
  keyfile = Pathname.new(parameters.first)
  MOSS.create(keyfile)
when 'git'
  MOSS.git_operation(parameters)
else
  raise "command #{action} unrecognized"
end
