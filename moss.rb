#!/usr/bin/env ruby
require 'pathname'
require 'tempfile'
require 'json'

def xdg_data_home
  ENV.fetch("XDG_DATA_HOME", "#{ENV['HOME']}/.local/share")
end

STORE = Pathname.new(ENV['MOSS_STORE'] || "#{xdg_data_home}/moss/store")

def identity_file
  value = ENV.fetch('MOSS_IDENTITY_FILE',  "#{xdg_data_home}/moss/identity")
  File.exist?(value) or
    raise "missing identity file (private key) at #{IDENTITY_FILE}, use age-keygen to create"
  value
end

def git_managed?
  STORE.join(".git").exist?
end

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

def write_secret(name, content)
  pathname = STORE.join("#{name}.age")
  pathname.dirname.mkpath
  IO.popen("age -a --recipients-file #{recipients_for_secret(name)} -o #{pathname.to_s}", "w") do |f|
    f.write(content)
  end
  if git_managed?
    Kernel.system("cd #{STORE.to_s} && git add #{pathname.relative_path_from(STORE).to_s.inspect} && git commit -m'new secret'")
  end
end

def find_in_subtree(subtree, filename)
  pathname = subtree.join(filename)
  case
  when pathname.readable?
    pathname
  when subtree.to_s >  STORE.to_s
    find_in_subtree(subtree.parent, filename)
  else
    nil
  end
end

def recipients_for_secret(name)
  pathname = STORE.join("#{name}.age")
  find_in_subtree(pathname.parent, ".recipients") or
    raise "Can't find .recipients for #{name}"
end

def read_secret(name)
  pathname = STORE.join("#{name}.age")
  File.exist?(pathname) or raise "Can't open #{pathname}: $!"
  `age -i #{identity_file} -d #{pathname}`
end

action, *parameters = ARGV
case action
when 'generate'
  file , len = parameters
  secret = random_alnum(len.to_i)
  print secret
  write_secret(file, secret)
when 'insert','add'
  file, = parameters
  secret = STDIN.read
  write_secret(file, secret)
when 'cat','show'
  file, = parameters
  STDOUT.write(read_secret(file))
when 'edit'
  file, = parameters
  content = read_secret(file)
  Tempfile.create(file.gsub(/[\W]/,"")) do |f|
    f.write(content)
    f.flush
    if Kernel.system(ENV['EDITOR'], f.path)
      f.rewind
      secret = f.read
      write_secret(file, secret)
    else
      raise "#{$!}"
    end
  end
when 'search','list'
  term = parameters.join(" ")
  files = Dir[STORE.join('**/*.age')].map {|n|
    Pathname.new(n).relative_path_from(STORE).sub_ext('').to_s
  }.filter {|f|
    f.match(Regexp.new(term))
  }
  files.each do |n|
    puts n
  end
when 'config'
  config = {
    store: STORE.to_s,
    identity_file: identity_file.to_s,
    git: git_managed?
  }
  puts JSON.generate(config)
when 'init'
  keyfile = Pathname.new(parameters.first)
  keyfile.exist? or raise "Cannot read identity at #{keyfile}"
  keyfile.read.match(/AGE-SECRET-KEY-1/) or
    raise "#{keyfile} does not appear to be an age identity"
  STORE.mkpath
  FileUtils.cp(keyfile,  STORE.parent.join("identity"))
  File.open(STORE.join(".recipients"), "w") do |f|
    f.write `age-keygen -y #{keyfile.to_s.inspect}`
  end
when 'git'
  Kernel.system("/usr/bin/env", "git", *parameters, {chdir: STORE})

else
  raise "command #{action} unrecognized"
end
