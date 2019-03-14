# frozen_string_literal: true

require 'net/ssh'
require 'net/sftp'
require 'timeout'
require 'sshake/error'
require 'sshake/logger'
require 'sshake/response'
require 'sshake/execution_options'

module SSHake
  class Session
    # The underlying net/ssh session
    #
    # @return [Net::SSH::Session]
    attr_reader :session

    # A logger for this session
    #
    # @return [Logger, nil]
    attr_accessor :logger

    # Specify the default behaviour for raising erors
    #
    # @return [Boolean]
    attr_accessor :raise_on_error

    # Create a new SSH session
    #
    # @return [Sshake::Session]
    def initialize(host, *args)
      @host = host
      @session_options = args
    end

    # Connect to the SSH server
    #
    # @return [void]
    def connect
      @session = Net::SSH.start(@host, *@session_options)
      true
    end

    # Is there an established SSH connection
    #
    # @return [Boolean]
    def connected?
      !@session.nil?
    end

    # Disconnect the underlying SSH connection
    #
    # @return [void]
    def disconnect
      begin
        @session.close
      rescue StandardError
        nil
      end
      @session = nil
      true
    end

    # Kill the underlying connection
    def kill!
      @session.shutdown!
      @session = nil
    end

    # Execute a command
    #
    def execute(commands, options = nil, &block)
      commands = [commands] unless commands.is_a?(Array)

      options = create_options(options, block)

      # Map sudo onto command
      if options.sudo_user
        commands = add_sudo_to_commands_array(commands, options.sudo_user)
      end

      # Construct a full command string to execute
      command = commands.join(' && ')

      # Log the command
      log :info, "\e[44;37m=> #{command}\e[0m"

      # Execute the command
      response = Response.new
      response.command = command
      connect unless connected?
      begin
        channel = nil
        Timeout.timeout(options.timeout) do
          channel = @session.open_channel do |ch|
            response.start_time = Time.now
            channel.exec(command) do |_, success|
              raise "Command \"#{command}\" was unable to execute" unless success

              ch.send_data(options.stdin) if options.stdin
              ch.eof!

              ch.on_data do |_, data|
                response.stdout += data
                options.stdout&.call(data)
                log :debug, data.gsub(/[\r]/, ''), tab: 4
              end

              ch.on_extended_data do |_, _, data|
                response.stderr += data.delete("\r")
                options.stderr&.call(data)
                log :warn, data, tab: 4
                if data =~ /^\[sudo\] password for/
                  ch.send_data "#{options.sudo_password}\n"
                end
              end

              ch.on_request('exit-status') do |_, data|
                response.exit_code = data.read_long&.to_i
                log :info, "\e[43;37m=> Exit code: #{response.exit_code}\e[0m"
              end

              ch.on_request('exit-signal') do |_, data|
                response.exit_signal = data.read_long
              end
            end
          end
          channel.wait
        end
      rescue Timeout::Error => e
        kill!
        response.exit_code = -255
      ensure
        response.finish_time = Time.now
      end

      if !response.success? && ((options.raise_on_error.nil? && @raise_on_error) || options.raise_on_error?)
        raise ExecutionError, response
      else
        response
      end
    end

    def write_data(path, data, options = nil, &block)
      connect unless connected?
      tmp_path = "/tmp/sshake-tmp-file-#{SecureRandom.hex(32)}"
      @session.sftp.file.open(path, 'w') { |f| f.write(data) }
      response = execute("mv #{tmp_path} #{path}", options, &block)
      response.success?
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

      prefix = "\e[45;37m[#{@host}]\e[0m"
      tabs = ' ' * (options[:tab] || 0)
      text.split(/\n/).each do |line|
        logger.send(type, prefix + tabs + line)
      end
    end
  end
end
