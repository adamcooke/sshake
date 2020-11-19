# frozen_string_literal: true

module SSHake
  module Mock
    class ExecutedCommand

      attr_reader :command, :environment, :response

      def initialize(command, environment, response)
        @command = command
        @environment = environment
        @response = response
      end

    end
  end
end
