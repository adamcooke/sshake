require 'sshake/base_session'
require 'sshake/mock/command_set'
require 'sshake/mock/environment'
require 'sshake/mock/unsupported_command_error'

module SSHake
  module Mock
    class Session < BaseSession

      attr_reader :command_set
      attr_reader :store
      attr_reader :written_files

      def initialize(**options)
        @command_set = options[:command_set] || CommandSet.new
        @store = {}
        @written_files = {}
        @connected = false
      end

      def connect
        @connected = true
      end

      def connected?
        @connected == true
      end

      def disconnect
        @connected = false
      end

      def kill!
        disconnect
      end

      def execute(commands, options = nil, &block)
        environment = Environment.new(self)

        options = create_options(options, block)
        environment.command = prepare_commands(commands, options)

        command, environment.captures = @command_set.match(environment.command)

        if command.nil?
          raise UnsupportedCommandError.new(environment.command)
        end

        response = command.make_response(environment)
        handle_response(response, options)
      end

      def write_data(path, data, options = nil, &block)
        connect unless connected?
        @written_files[path] = data
        true
      end

    end
  end
end
