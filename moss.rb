#!/usr/bin/env ruby
require 'pathname'
require 'tempfile'
require 'json'

# don't change these lines without changing the sed commands in Makefile
AGE='age'
AGE_KEYGEN='age-keygen'
GIT='git'

def xdg_data_home
  ENV.fetch("XDG_DATA_HOME", "#{ENV['HOME']}/.local/share")
end

def identity_file
  value = ENV.fetch('MOSS_IDENTITY_FILE',  "#{xdg_data_home}/moss/identity")
  File.exist?(value) or
    raise "missing identity file (private key) at #{IDENTITY_FILE}, use age-keygen to create"
  value
end

class Moss
  attr_reader :root

  def initialize(root)
    @root = Pathname.new(root)
  end

  # This is the method that "moss init" calls, which could be better
  # named. "initialize" would be a good name if it weren't special to
  # Ruby

  def create(keyfile)
    keyfile.exist? or raise "Cannot read identity at #{keyfile}"
    keyfile.read.match(/AGE-SECRET-KEY-1/) or
      raise "#{keyfile} does not appear to be an age identity"
    store.mkpath
    FileUtils.cp(keyfile,  store.parent.join("identity"))
    File.open(store.join(".recipients"), "w") do |f|
      f.write `#{AGE_KEYGEN} -y #{keyfile.to_s.inspect}`
    end
  end

  def store
    root.join("store")
  end

  def git_managed?
    store.join(".git").exist?
  end

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
    IO.popen("#{AGE} -a --recipients-file #{recipients_for_secret(name)} -o #{pathname.to_s}", "w") do |f|
      f.write(content)
    end
    if git_managed?
      Kernel.system("cd #{store.to_s} && git add #{pathname.relative_path_from(store).to_s.inspect} && git commit -m'new secret'")
    end
  end

  def read_secret(name)
    pathname = store.join("#{name}.age")
    File.exist?(pathname) or raise "Can't open #{pathname}: $!"
    `#{AGE} -i #{identity_file} -d #{pathname}`
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
end




MOSS = Moss.new(Pathname.new(ENV['MOSS_STORE'] || "#{xdg_data_home}/moss/store").parent)

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
  Kernel.system(GIT, *parameters, {chdir: MOSS.store})
else
  raise "command #{action} unrecognized"
end
