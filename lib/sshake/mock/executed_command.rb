module SSHake
  module Mock
    class ExecutedCommand

      attr_reader :command
      attr_reader :environment
      attr_reader :response

      def initialize(command, environment, response)
        @command = command
        @environment = environment
        @response = response
      end

    end
  end
end
