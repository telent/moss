MOSS="./moss.rb"

require 'tmpdir'
require 'fileutils'

def shell(s, permit_failure: false)
  output = IO.popen(["bash", "-c", s], "r", 2 => 1) do |f| f.read end
  (permit_failure || $?.exitstatus.zero?) or
    raise "#{$?} : #{@i_see}"
  output
end

IDENTITY_FILE = "fixtures/keys/me.key"

def store_path(s)
  Pathname.new(ENV["MOSS_HOME"]).join("store", s)
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

Given("I set MOSS_HOME to a unique temporary pathname") do
  ENV["MOSS_HOME"] = Dir.mktmpdir
end

Given("I am using a temporary password store") do
  ENV["MOSS_HOME"] = Dir.mktmpdir

  add_to_store("../identity", File.read(IDENTITY_FILE))
  add_to_store(".recipients", recipient_for_identity(IDENTITY_FILE))
end

Given("I am using the example password store") do
  ENV["MOSS_HOME"] = "fixtures"
end

Given('there is a secret for {string}') do |name|
  shell "#{MOSS} generate #{name} 20"
end

When("I generate a secret for {string} with length {int}") do |name,  length|
  @stored_secret_name = name
  @i_see = shell "#{MOSS} generate #{name} #{length}"
end

When("I delete the secret for {string}") do |name|
  @i_see = shell "#{MOSS} rm #{name}"
end

Then('{string} does not exist') do |path|
  expect(store_path(path)).not_to exist
end

# yes, this step is a Given and a When with different text
Given("there is a secret for {string} with content {string}") do |name, content|
  @stored_secret_name = name
  shell "echo -n #{content} | #{MOSS} insert #{name.inspect}"
end

When("I store a secret for {string} with content {string}") do |name, content|
  @stored_secret_name = name
  shell "echo -n #{content} | #{MOSS} insert #{name.inspect}"
end

When("I force store a secret for {string} with content {string}") do |name, content|
  @stored_secret_name = name
  shell "echo -n #{content} | #{MOSS} insert #{name.inspect} --force"
end

Then("I cannot store a secret for {string} with content {string}") do |name, content|
  @stored_secret_name = name
  shell "echo -n #{content} | #{MOSS} insert #{name.inspect}", permit_failure: true
  warn $?
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
  plaintext = shell "age -i #{IDENTITY_FILE} -d #{path_name.to_s.inspect}"
  expect(plaintext).to eq expected
end

def decrypt(secret_name, keyfile)
  path_name = store_path(secret_name + '.age')
  contents = File.read(path_name)
  expect(contents).to match /AGE ENCRYPTED FILE/
  shell "age -i fixtures/keys/#{keyfile} -d #{path_name.to_s.inspect}"
end

Then("I can decrypt it with key {string} to {string}") do |keyfile, expected|
  expect(decrypt(@stored_secret_name, keyfile)).to eq expected
end

Then("I can decrypt {string} with key {string} to {string}") do |secret_name, keyfile, expected|
  expect(decrypt(secret_name, keyfile)).to eq expected
end

Then("I cannot decrypt it with key {string}") do |keyfile|
  path_name = store_path(@stored_secret_name + '.age')
  contents = File.read(path_name)
  expect(contents).to match /AGE ENCRYPTED FILE/
  # we expect age to fail, redirect stderr to avoid messing up test output
  shell "!  age -i fixtures/keys/#{keyfile} -d #{path_name.to_s.inspect} 2>&1"
end

Then("{string} plaintext matches {word}") do |name, re|
  path_name = store_path(name)
  contents = File.read(path_name)
  expect(contents).to match /AGE ENCRYPTED FILE/
  shell "age -i #{IDENTITY_FILE} -d #{path_name.to_s.inspect}"
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

When('I add a recipient for the identity {string}') do |keyfile|
  add_to_store(".recipients",
               store_path(".recipients").read +
               "\n" +
               recipient_for_identity("fixtures/keys/#{keyfile}"))
end


Given("the store is version-controlled") do
  shell "cd #{ENV["MOSS_HOME"]}/store && git init --initial-branch=main"
end

Then("the change to {string} is committed to version control") do |name|
  log = shell "cd #{ENV["MOSS_HOME"]}/store && git log #{name}"
  expect(log).to match /new secret/
end

Given("I do not specify a store") do
  ENV.delete('MOSS_HOME')
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
  expect(Pathname.new(ENV['MOSS_HOME']).join("store")).to be_directory
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

Then("the store file {string} is readable only by me") do |store_file|
  pathname = store_path(store_file)
  mode =  File.stat(pathname).mode
  expect(mode & 077).to be_zero
end

Then("my identity file is readable only by me") do
  pathname= store_path("../identity")
  mode =  File.stat(pathname).mode
  expect(mode & 077).to be_zero
end

When("I run {string}") do |command|
  # don't fail if error returns, as we need to test that
  @i_see = IO.popen(["bash", "-c", "#{command.sub(/\Amoss/,  MOSS)} 2>&1"],
                    "r") do |f| f.read end
  @exit_status = $?.exitstatus
end

Then("it shows a usage message for {string}") do |command|
  expect(@exit_status).to be > 0
  expect(@i_see).to match /usage: moss #{command} \<file\>/
end

When('I re-encrypt the store') do
  @i_see = shell "#{MOSS} rebuild"
end
