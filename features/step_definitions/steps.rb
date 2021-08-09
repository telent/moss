MOSS="./moss.rb"

require 'tmpdir'
require 'fileutils'

def shell(s)
  output = %x{bash -c #{s.inspect}}
  $?.exitstatus.zero? or raise "#{$?} : #{@i_see}"
  output
end

def store_path(s)
  Pathname.new(ENV["MOSS_STORE"]).join(s)
end

Given("I am using a temporary password store") do
  ENV["MOSS_STORE"] = Dir.mktmpdir
  Dir.mkdir(store_path(".age"))
  FileUtils.cp("fixtures/store/.age/identity", store_path(".age/identity"))
end

Given("I am using the example password store") do
  ENV["MOSS_STORE"] = "fixtures/store"
end

When("I generate a secret for {string} with length {int}") do |name,  length|
  @i_see = shell "#{MOSS} generate #{name} #{length}"
end

When("I store a secret for {string} with content {string}") do |name, content|
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
  plaintext = shell "age -i #{store_path(".age/identity")} -d #{path_name}"
  expect(plaintext).to eq expected
end

Then("{string} plaintext matches {word}") do |name, re|
  path_name = store_path(name)
  contents = File.read(path_name)
  expect(contents).to match /AGE ENCRYPTED FILE/
  shell "age -i #{store_path(".age/identity")} -d #{path_name}"
  expect(@i_see).to match Regexp.new(re)
end

When("I view the secret {string}") do |name|
  @i_see = shell "#{MOSS} cat #{name}"
end

When("I search for {string}") do |term|
  @i_see = shell "#{MOSS} search #{term}"
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
