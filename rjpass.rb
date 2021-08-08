#!/usr/bin/env ruby
require 'pathname'
require 'tempfile'

STORE = Pathname.new(ENV['RJPASS_STORE'] || "/tmp/store")
IDENTITY = "age1wc392uhfm04sy5nmpu86ea077ymjxs6e3gnda54jvpmuqchj9d5s6d0q2x"

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
  IO.popen("age -a -r #{IDENTITY} -o #{pathname.to_s}", "w") do |f|
    f.write(content)
  end
end

def read_secret(name)
  pathname = STORE.join("#{name}.age")
  File.exist?(pathname) or raise "Can't open #{pathname}: $!"
  `age -i #{STORE.join(".age/identity")} -d #{pathname}`
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
when 'search'
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
