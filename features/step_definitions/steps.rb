MOSS="./moss.rb"

require 'tmpdir'
require 'fileutils'

def shell(s)
  output = %x{bash -c #{s.inspect}}
  $?.exitstatus.zero? or raise "#{$?} : #{@i_see}"
  output
end

IDENTITY_FILE = "fixtures/keys/me.key"
ENV['MOSS_IDENTITY_FILE'] = IDENTITY_FILE

def store_path(s)
  Pathname.new(ENV["MOSS_STORE"]).join(s)
end

def add_to_store(path, content)
  fullpath = Pathname.new(store_path(path))
  fullpath.parent.mkpath
  File.open(fullpath, "wb") do |f|
    f.write(content)
  end
end

def recipient_for_identity(identity_file)
  File.open(identity_file).read.match(/(age1.+)$/).captures.first
end


Given("I am using a temporary password store") do
  ENV["MOSS_STORE"] = Dir.mktmpdir
  add_to_store(".recipients", recipient_for_identity("fixtures/keys/me.key"))
end

Given("I am using the example password store") do
  ENV["MOSS_STORE"] = "fixtures/store"
end

When("I generate a secret for {string} with length {int}") do |name,  length|
  @stored_secret_name = name
  @i_see = shell "#{MOSS} generate #{name} #{length}"
end

When("I store a secret for {string} with content {string}") do |name, content|
  @stored_secret_name = name
  shell "echo -n #{content} | #{MOSS} insert #{name}"
end

Then("I see a {int} character string") do |len|
  expect(@i_see.length).to eq len
end

Then("I see the string {string}") do |s|
  expect(@i_see).to match(s)
end

Then("{string} plaintext is {string}") do |name, expected|
  path_name = store_path(name)
  contents = File.read(path_name)
  expect(contents).to match /AGE ENCRYPTED FILE/
  plaintext = shell "age -i #{IDENTITY_FILE} -d #{path_name}"
  expect(plaintext).to eq expected
end

Then("I can decrypt it with key {string} to {string}") do |keyfile, expected|
  path_name = store_path(@stored_secret_name + '.age')
  contents = File.read(path_name)
  expect(contents).to match /AGE ENCRYPTED FILE/
  plaintext = shell "age -i fixtures/keys/#{keyfile} -d #{path_name}"
  expect(plaintext).to eq expected
end

Then("I cannot decrypt it with key {string}") do |keyfile|
  path_name = store_path(@stored_secret_name + '.age')
  contents = File.read(path_name)
  expect(contents).to match /AGE ENCRYPTED FILE/
  # we expect age to fail, redirect stderr to avoid messing up test output
  shell "!  age -i fixtures/keys/#{keyfile} -d #{path_name} 2>&1"
end

Then("{string} plaintext matches {word}") do |name, re|
  path_name = store_path(name)
  contents = File.read(path_name)
  expect(contents).to match /AGE ENCRYPTED FILE/
  shell "age -i #{IDENTITY_FILE} -d #{path_name}"
  expect(@i_see).to match Regexp.new(re)
end

When("I view the secret {string}") do |name|
  @i_see = shell "#{MOSS} cat #{name}"
end

When("I search for {string}") do |term|
  @i_see = shell "#{MOSS} search #{term}"
end

When("I list the secrets") do 
  @i_see = shell "#{MOSS} list"
end

When("I edit {string}") do |name|
  ENV["EDITOR"] = "./fixtures/fakedit.sh"
  @i_see = shell "#{MOSS} edit #{name}"
end

Then("the editor opens a temporary file containing {string}") do |expected|
  magic, pathname, content = @i_see.split("\0")
  # we test for this magic string to make sure that our fake editor was
  # invoked
  expect(magic).to eq('fakedit-magic')
  expect(pathname).to start_with(ENV['TMPDIR'])
  expect(content).to eq(expected)
end

Given("there are recipient files in different subtrees") do |table|
  table.hashes.each do |row|
    keys = row["identity"].split(/, */)
    recipients = keys.map { |k|
      recipient_for_identity("fixtures/keys/#{k}")
    }.join("\n")
    add_to_store("#{row['pathname']}/.recipients", recipients)
  end
end
