# frozen_string_literal: true

require 'net/ssh'
require 'net/sftp'
require 'timeout'
require 'sshake/error'
require 'sshake/response'
require 'sshake/base_session'

module SSHake
  class Session < BaseSession

    # The underlying net/ssh session
    #
    # @return [Net::SSH::Session]
    attr_reader :session

    # Return the host to connect to
    #
    # @return [String]
    attr_reader :host

    # Create a new SSH session
    #
    # @return [Sshake::Session]
    def initialize(host, username = nil, **options)
      super
      @host = host
      @username = username
      @session_options = options
      @session_options.delete(:klogger)
    end

    # Return the username for the connection
    #
    # @return [String]
    def user
      @user || ENV.fetch('USER', nil)
    end

    # Return the port that will be connected to
    #
    # @return [Integer]
    def port
      @session_options[:port] || 22
    end

    # Connect to the SSH server
    #
    # @return [void]
    def connect
      klogger.debug 'Connecting', id: @id, host: @host, user: @user, port: @session_options[:port] || 22
      @session = Net::SSH.start(@host, user, @session_options)
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
      return false if @session.nil?

      begin
        klogger.debug 'Closing connection', id: @id, host: @host
        @session.close
        klogger.debug 'Connection closed', id: @id, host: @host
      rescue StandardError => e
        logger.exception(e, 'Connection not closed')
        nil
      end
      @session = nil
      true
    end

    # Kill the underlying connection
    def kill!
      klogger.debug 'Attemping to shutdown', id: @id, host: @host
      @session.shutdown!
      klogger.debug 'Shutdown success', id: @id, host: @host
      @session = nil
    end

    # rubocop:disable Metrics/AbcSize
    def execute(commands, options = nil, &block)
      options = create_options(options, block)
      command_to_execute = prepare_commands(commands, options)

      # Execute the command
      response = Response.new
      response.command = command_to_execute
      connect unless connected?

      klogger.group(id: @id, host: @host) do
        klogger.info 'Executing command', command: command_to_execute, timeout: options.timeout

        begin
          channel = nil

          Timeout.timeout(options.timeout) do
            channel = @session.open_channel do |ch|
              response.start_time = Time.now

              channel.exec(command_to_execute) do |_, success|
                raise "Command \"#{command_to_execute}\" was unable to execute" unless success

                ch.send_data(options.stdin) if options.stdin

                if options.file_to_stream.nil? && options.sudo_password.nil?
                  klogger.debug 'Sending EOF to channel'
                  ch.eof!
                end

                ch.on_data do |_, data|
                  response.stdout += data
                  options.stdout&.call(data)
                  klogger.debug "[stdout] #{data.gsub(/\r/, '').strip}"
                end

                ch.on_extended_data do |_, _, data|
                  response.stderr += data.delete("\r")
                  options.stderr&.call(data)
                  klogger.debug "[stderr] #{data.gsub(/\r/, '').strip}"
                  if options.sudo_password && data =~ /^\[sshake-sudo-password\]:\s\z/
                    klogger.debug 'Sending sudo password', length: options.sudo_password.length
                    ch.send_data "#{options.sudo_password}\n"

                    if options.file_to_stream.nil?
                      klogger.debug 'Sending EOF after password'
                      ch.eof!
                    end
                  end
                end

                ch.on_request('exit-status') do |_, data|
                  response.exit_code = data.read_long&.to_i
                  klogger.info 'Exited', exit_code: response.exit_code
                end

                ch.on_request('exit-signal') do |_, data|
                  response.exit_signal = data.read_long
                end

                if options.file_to_stream
                  ch.on_process do |_, data|
                    next if ch.eof?

                    if ch.output.length < 128 * 1024
                      if data = options.file_to_stream.read(1024 * 1024)
                        ch.send_data(data)
                        response.bytes_streamed += data.bytesize
                      else
                        ch.eof!
                      end
                    end
                  end
                end
              end
            end
            channel.wait
          end
        rescue Timeout::Error
          klogger.debug 'Command timed out'
          kill!
          response.timeout!
        ensure
          response.finish_time = Time.now
        end
      end

      handle_response(response, options)
    end
    # rubocop:enable Metrics/AbcSize

    def write_data(path, data, options = nil, &block)
      connect unless connected?
      tmp_path = "/tmp/sshake-tmp-file-#{SecureRandom.hex(32)}"
      @session.sftp.file.open(tmp_path, 'w') do |f|
        d = data.dup.force_encoding('BINARY')
        f.write(d.slice!(0, 1024)) until d.empty?
      end
      response = execute("mv #{tmp_path} #{path}", options, &block)
      response.success?
    end

    class << self

      def create(*args)
        session = new(*args)

        if recorder = Thread.current[:sshake_recorder]
          return RecordedSession.new(recorder, session)
        end

        session
      end

    end

  end
end
