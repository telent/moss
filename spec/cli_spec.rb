require "moss"

class CLI1
  class << self
    @@commands = {}
    def command(command_name, docstring, &blk)
      define_method command_name, &blk
      @@commands[command_name] = { doc: docstring }
    end
  end

  def parse_arguments(argv)
    name = argv.first.to_sym
    args = argv.drop(1)
    raise NoMethodError unless @@commands.key?(name)
    arg_signature = method(name).parameters

    return [ name, [] ] if arg_signature.empty?
          
    flags = argv.reduce({}) {|m, flag|
      key, val= flag.match(/\A--(\w+)(?:=(.+))?/)&.captures
      key ?
        m.merge(key.to_sym => val ? val : :key_present) :
        m
    }

    payload = arg_signature.reduce({}) { |m, (type, name)|
      case type
      when :rest
        args
      when :keyreq
        args.first ? m.merge(name => args.shift) : m
      when :key
        m
      end
    }
    [ name,
      payload.respond_to?(:merge) ? flags.merge(payload) : payload ]
  end

  def params_to_s(meth)
    meth.parameters.map {|(type, name)|
      case type
      when :req, :keyreq
        "<#{name}>"
      when :rest
        "<#{name}...>"
      when :key
        "[--#{name}]"
      end
    }.join(" ")
  end
  
  def describe_usage(method_name)
    param_string = params_to_s(method(method_name))
    "#{method_name} #{param_string}"
  end
  
  UsageError = Class.new(RuntimeError)
  
  def dispatch(argv)
    name, payload = parse_arguments(argv)
    begin
      self.public_send(name,payload)
    rescue ArgumentError => e
      raise UsageError, "usage: moss #{describe_usage(name)}"
    end
  end

  def usage
    command_texts = @@commands.map { |name, command|
      # unless name == command[:name] # skip aliases
      sprintf "  %-40s - %s",
              "#{name} #{describe_usage(name)}",
              command[:doc]
    }
    
    usage_header+ command_texts.join("\n")
  end
  
end
    
cli = CLI1.new
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
  end
end


RSpec.describe CLI1 do
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

    it "works for flags" do
      expect(cli.dispatch ["mail", "dan", "--subject=hello dan"])
        .to eq "/usr/lib/sendmail dan -s \"hello dan\""
    end

    it "complains if wrong params" do
      expect { cli.dispatch ["mail"] }
        .to raise_exception(CLI1::UsageError, /usage: moss mail <rcpt> \[--subject\]/)            
    end
  end

  describe "documentation" do
    subject { cli.usage }

    it { should match /send email/ }
    it { should match /wait patiently/ }
  end
end
