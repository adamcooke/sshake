require 'net/ssh/errors'
require 'sshake/base_session'
require 'sshake/mock/command_set'
require 'sshake/mock/environment'
require 'sshake/mock/unsupported_command_error'
require 'sshake/mock/executed_command'

module SSHake
  module Mock
    class Session < BaseSession

      attr_reader :command_set
      attr_reader :store
      attr_reader :written_files
      attr_reader :executed_commands

      def initialize(**options)
        @options = options
        @command_set = options[:command_set] || CommandSet.new
        @executed_commands = []
        @store = {}
        @written_files = {}
        @connected = false
        yield(self) if block_given?
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
        connect unless connected?

        environment = Environment.new(self)

        environment.options = create_options(options, block)
        environment.command = prepare_commands(commands, environment.options, :add_sudo => false)

        command, environment.captures = @command_set.match(environment.command)

        if command.nil?
          raise UnsupportedCommandError.new(environment.command)
        end

        response = command.make_response(environment)
        @executed_commands << ExecutedCommand.new(command, environment, response)
        handle_response(response, environment.options)
      end

      def write_data(path, data, options = nil, &block)
        connect unless connected?
        @written_files[path] = data
        true
      end

      def find_executed_commands(matcher)
        if matcher.is_a?(Regexp)
          matcher = /\A#{matcher}\z/
        else
          matcher = /\A#{Regexp.escape(matcher.to_s)}\z/
        end
        @executed_commands.select do |command|
          command.environment.command =~ matcher
        end
      end

      def has_executed_command?(matcher)
        find_executed_commands(matcher).size > 0
      end

    end
  end
end
