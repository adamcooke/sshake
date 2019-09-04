require 'sshake/mock/command'

module SSHake
  module Mock
    class CommandSet

      def initialize
        @commands = []
      end

      def add(matcher, &block)
        command = Command.new(matcher, &block)
        @commands << command
        command
      end

      def match(given_command)
        @commands.each do |command|
          if matches = command.match(given_command)
            return [command, matches]
          end
        end
        nil
      end

    end
  end
end
