require 'sshake/error'

module SSHake
  module Mock
    class UnsupportedCommandError < Error

      def initialize(command)
        @command = command
      end

      def to_s
        "Executed command is not support by the mock session (`#{@command}`)"
      end

    end
  end
end
