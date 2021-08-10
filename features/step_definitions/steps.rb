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
  File.open(identity_file).read.match(/(age1.+)$/).captures.first or
    raise "can't get pubkey for identity #{identity_file}"
end



Given("I have the identity {string}") do |keyfile|
  @identity_path = "fixtures/keys/#{keyfile}"
end

Given("I set MOSS_STORE to a unique temporary pathname") do
  ENV["MOSS_STORE"] = Dir.mktmpdir + "/store"
end

Given("I am using a temporary password store") do
  @identity_path ||= "fixtures/keys/me.key"
  ENV["MOSS_STORE"] = Dir.mktmpdir + "/store"
  add_to_store(".recipients", recipient_for_identity(@identity_path))
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

Given("the store is version-controlled") do
  shell "cd #{ENV["MOSS_STORE"]} && git init --initial-branch=main"
end

Then("the change to {string} is committed to version control") do |name|
  log = shell "cd #{ENV["MOSS_STORE"]} && git log #{name}"
  expect(log).to match /new secret/
end

Given("I do not specify a store") do
  ENV.delete('MOSS_STORE')
end

Then("the store directory is under XDG_DATA_HOME") do
  ENV["XDG_DATA_HOME"] = "/tmp/#{6.times.map { rand(36).to_s(36) }.join}"
  result = JSON.load(shell "#{MOSS} config")
  store = result["store"]
  expect(store).to start_with(ENV["XDG_DATA_HOME"])
end

When("I create a moss instance with identity {string}") do |keyfile|
  shell "#{MOSS} init fixtures/keys/#{keyfile}"
end

When("I interactively create a moss instance with identity {string} and passphrase {string}") do |keyfile, passphrase|
  shell "expect moss-init-with-passphrase.expect fixtures/keys/#{keyfile} #{passphrase.inspect}"
end

Then("the instance store exists") do
  expect(Pathname.new(ENV['MOSS_STORE'])).to be_directory
end

Then("the instance identity is {string}") do |keyfile|
  expect(store_path("../identity").read).to eq File.read("fixtures/keys/#{keyfile}")
end

Then("the store root has .recipients for the identity {string}") do |keyfile|
  expected = `age-keygen -y fixtures/keys/#{keyfile.inspect}`
  expect(store_path(".recipients").read).to eq expected
end

Then("the store root has recipient {string}") do |recipient|
  expect(store_path(".recipients").read).to match recipient
end

Then("I can run git {string}") do |command|
  @i_see = shell "#{MOSS} git #{command}"
end
