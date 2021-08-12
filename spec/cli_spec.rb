require "moss"

class CLI1
  class << self
    @@commands = {}
    def command(command_name, &blk)
      define_method command_name, &blk
      @@commands[command_name] = { }
    end
  end

  def parse_arguments(argv)
    name = argv.first.to_sym
    args = argv.drop(1)
    raise NoMethodError unless @@commands.key?(name)
    arg_signature = method(name).parameters

    return [ name, [] ] if arg_signature.empty?
          
    flags = argv.reduce({}) {|m, flag|
      matchdata = flag.match(/\A--(\w+)(?:=(.+))?/)
      if matchdata
        key, val = matchdata.captures
        key ?
          m.merge(key.to_sym => val ? val : :key_present) :
          m
      else
        m
      end
    }

    payload = arg_signature.reduce({}) { |m, (type, name)|
      case type
      when :rest
        args
      when :keyreq
        m.merge(name => args.shift)
      when :key
        m
      end
    }
    [ name,
      payload.respond_to?(:merge) ? flags.merge(payload) : payload ]
  end

  def dispatch(argv)
    name, payload = parse_arguments(argv)
    self.public_send(name, *payload)
  end

end
    
cli = CLI1.new
class <<cli 
  command :greet do |firstname:, lastname:|
    #
  end
  command :hang do |tight: false|
    #
  end
  command :encrypt do |file:, signed: false|
    # 
  end
  command :mail do |rcpt:, subject: "text/plain"|
  end
  command :git do |*command|
  end
  command :help do
  end
end


RSpec.describe CLI1 do
  describe "dispatching" do

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
end
