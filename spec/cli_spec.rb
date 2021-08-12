require "moss"

cli = CLI.new
class <<cli
  def usage_header
    "Store and retrieve encrypted secrets\n\n" +
      "Usage: moss [command] [parameters]...\n\n"
  end

  command :greet, "say hello" do |firstname:, lastname:|
    "hello, #{firstname} #{lastname}"
  end
  command :hang, "wait patiently" do |tight: false|
    #
  end
  command :encrypt, "scramble a file" do |file:, signed: false|
    #
  end
  command :mail, "send email" do |rcpt:, subject: "(no subject)"|
    "/usr/lib/sendmail #{rcpt} -s #{subject.inspect}"
  end
  command :git, "perform a git operation" do |*command|
    command.join(":")
  end
  command :help, "show this message" do
    "there is no help"
  end
end


RSpec.describe CLI do
  describe "parameter parsing" do

    it "parses positional parameters" do
      expect(cli.parse_arguments %w(greet ringo starr)).
        to eq [:greet, {firstname: "ringo",
                        lastname: "starr"}]
    end

    it "parses valueless flags" do
      expect(cli.parse_arguments %w(hang --tight)).
        to match([:hang, have_key(:tight)])
      expect(cli.parse_arguments %w(hang)).
        to match([:hang, {}])
      expect(cli.parse_arguments %w(encrypt foo.txt --signed)).
        to match([:encrypt, { file: "foo.txt", signed: anything }])
      expect(cli.parse_arguments %w(encrypt foo.txt)).
        to match([:encrypt, { file: "foo.txt" }])
    end

    it "parses flags with values" do
      expect(cli.parse_arguments ["mail", "dan", "--subject=hello dan"]).
        to match([:mail, { rcpt: "dan", subject: "hello dan" }])
    end

    it "parses rest parameters" do
      expect(cli.parse_arguments ["git", "init", "--bare", "-mmain"]).
        to match([:git, ["init", "--bare", "-mmain"]])
    end

    it "parses when no parameters" do
      expect(cli.parse_arguments %w(help)).
        to match([:help, []])
    end
  end

  describe "dispatching" do
    it "calls the relevant command" do
      expect(cli.dispatch %w(greet jane eyre)).to eq "hello, jane eyre"
    end

    it "works for rest parameters" do
      expect(cli.dispatch %w(git init --bare))
        .to eq "init:--bare"
    end

    it "works for no parameters" do
      expect(cli.dispatch %w(help))
        .to eq "there is no help"
    end

    it "works for flags" do
      expect(cli.dispatch ["mail", "dan", "--subject=hello dan"])
        .to eq "/usr/lib/sendmail dan -s \"hello dan\""
    end

    it "complains if wrong params" do
      expect { cli.dispatch ["mail"] }
        .to raise_exception(CLI::UsageError, /usage: moss mail <rcpt> \[--subject\]/)
    end
  end

  describe "documentation" do
    subject { cli.usage }

    it { should match /send email/ }
    it { should match /wait patiently/ }
  end
end
