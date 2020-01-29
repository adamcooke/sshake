require 'securerandom'
require 'sshake/logger'
require 'sshake/execution_options'

module SSHake
  class BaseSession
    # A logger for this session
    #
    # @return [Logger, nil]
    attr_accessor :logger

    # Specify the default behaviour for raising erors
    #
    # @return [Boolean]
    attr_accessor :raise_on_error

    # Connect to the SSH server
    #
    # @return [void]
    def connect
      raise "Override #connect in sub-sessions"
    end

    # Is there an established SSH connection
    #
    # @return [Boolean]
    def connected?
      raise "Override #connected? in sub-sessions"
    end

    # Disconnect the underlying SSH connection
    #
    # @return [void]
    def disconnect
      raise "Override #disconnect in sub-sessions"
    end

    # Kill the underlying connection
    def kill!
      raise "Override #kill! in sub-sessions"
    end

    # Execute a command
    #
    def execute(commands, options = nil, &block)
      raise "Override #execute in sub-sessions"
    end

    def write_data(path, data, options = nil, &block)
      raise "Override #write_data in sub-sessions"
    end

    private

    def add_sudo_to_commands_array(commands, user)
      commands.map do |command|
        "sudo -u #{user} --stdin #{command}"
      end
    end

    def create_options(hash, block)
      if block && hash
        raise Error, 'You cannot provide a block and options'
      elsif block
        ExecutionOptions.from_block(&block)
      elsif hash.is_a?(Hash)
        ExecutionOptions.from_hash(hash)
      else
        ExecutionOptions.new
      end
    end

    def log(type, text, options = {})
      logger = @logger || SSHake.logger
      return unless logger

      prefix = "[#{@host}]"

      if log_id = Thread.current[:log_id]
        prefix = "[#{log_id}] #{prefix} "
      end

      text.split(/\n/).each do |line|
        logger.send(type, prefix + line)
      end
    end

    def tagged
      Thread.current[:log_id] = SecureRandom.hex(4)
      yield
    ensure
      Thread.current[:log_id] = nil
    end

    def prepare_commands(commands, execution_options, **options)
      commands = [commands] unless commands.is_a?(Array)

      # Map sudo onto command
      if execution_options.sudo_user && options[:add_sudo] != false
        commands = add_sudo_to_commands_array(commands, execution_options.sudo_user)
      end

      # Construct a full command string to execute
      commands.join(' && ')
    end

    def handle_response(response, options)
      if !response.success? && ((options.raise_on_error.nil? && @raise_on_error) || options.raise_on_error?)
        raise ExecutionError, response
      else
        response
      end
    end

  end
end
