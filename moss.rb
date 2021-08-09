#!/usr/bin/env ruby
require 'pathname'
require 'tempfile'


STORE = Pathname.new(ENV['MOSS_STORE'] || "/tmp/store").realpath
IDENTITY_FILE = ENV['MOSS_IDENTITY_FILE']

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
  `age -i #{IDENTITY_FILE} -d #{pathname}`
end

action, *parameters = ARGV
case action
when 'generate'
  file , len = parameters
  secret = random_alnum(len.to_i)
  print secret
  write_secret(file, secret)
when 'insert'
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
else
  raise "command #{action} unrecognized"
end
