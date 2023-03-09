# frozen_string_literal: true

require 'securerandom'
require 'klogger'
require 'sshake/klogger'
require 'sshake/execution_options'

module SSHake
  class BaseSession

    # A logger for this session
    #
    # @return [Klogger, nil]
    attr_accessor :klogger

    # An ID for this session
    #
    # @return [String]
    attr_reader :id

    # Specify the default behaviour for raising erors
    #
    # @return [Boolean]
    attr_accessor :raise_on_error

    def initialize(*_args, klogger: nil, **_options)
      @id = SecureRandom.hex(4)
      @klogger = klogger || SSHake.klogger
    end

    # Connect to the SSH server
    #
    # @return [void]
    def connect
      raise 'Override #connect in sub-sessions'
    end

    # Is there an established SSH connection
    #
    # @return [Boolean]
    def connected?
      raise 'Override #connected? in sub-sessions'
    end

    # Disconnect the underlying SSH connection
    #
    # @return [void]
    def disconnect
      raise 'Override #disconnect in sub-sessions'
    end

    # Kill the underlying connection
    def kill!
      raise 'Override #kill! in sub-sessions'
    end

    # Execute a command
    #
    def execute(_commands, _options = nil)
      raise 'Override #execute in sub-sessions'
    end

    def write_data(_path, _data, _options = nil)
      raise 'Override #write_data in sub-sessions'
    end

    private

    def add_sudo_to_commands_array(commands, user, password = nil)
      sudo_prefix = "sudo -u #{user}"
      unless password.nil?
        sudo_prefix += " --stdin -p '[sshake-sudo-password]: ' "
      end
      commands.map do |command|
        "#{sudo_prefix} #{command}"
      end
    end

    def create_options(hash, block)
      if block && hash
        raise Error, 'You cannot provide a block and options'
      end

      if block
        ExecutionOptions.from_block(&block)
      elsif hash.is_a?(Hash)
        ExecutionOptions.from_hash(hash)
      else
        ExecutionOptions.new
      end
    end

    def prepare_commands(commands, execution_options, **options)
      commands = [commands] unless commands.is_a?(Array)

      # Map sudo onto command
      if execution_options.sudo_user && options[:add_sudo] != false
        commands = add_sudo_to_commands_array(commands, execution_options.sudo_user, execution_options.sudo_password)
      end

      # Construct a full command string to execute
      commands.join(' && ')
    end

    def handle_response(response, options)
      if !response.success? && ((options.raise_on_error.nil? && @raise_on_error) || options.raise_on_error?)
        raise ExecutionError, response
      end

      response
    end

  end
end
