require 'net/ssh/errors'
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
        @options = options
        @command_set = options[:command_set] || CommandSet.new
        @store = {}
        @written_files = {}
        @connected = false
      end

      def connect
        case @options[:connection_error]
        when :timeout
          raise Net::SSH::ConnectionTimeout
        when :authentication_failed
          raise Net::SSH::AuthenticationFailed
        when :connection_refused
          raise Errno::ECONNREFUSED
        when :host_unreachable
          raise Errno::EHOSTUNREACH
        else
          @connected = true
        end
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

        environment.options = create_options(options, block)
        environment.command = prepare_commands(commands, environment.options, :add_sudo => false)

        command, environment.captures = @command_set.match(environment.command)

        if command.nil?
          raise UnsupportedCommandError.new(environment.command)
        end

        response = command.make_response(environment)
        handle_response(response, environment.options)
      end

      def write_data(path, data, options = nil, &block)
        connect unless connected?
        @written_files[path] = data
        true
      end

    end
  end
end
