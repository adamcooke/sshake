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
    def initialize(host, username_or_options = {}, options_with_username = {})
      super
      @host = host
      if username_or_options.is_a?(String)
        @user = username_or_options
        @session_options = options_with_username
      else
        @user = username_or_options.delete(:user)
        @session_options = username_or_options
      end
    end

    # Return the username for the connection
    #
    # @return [String]
    def user
      @user || ENV['USER']
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
      log :debug, "Creating connection to #{@host}"
      log :debug, "Session options: #{@session_options.inspect}"
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
        log :debug, 'Closing connectiong'
        @session.close
        log :debug, 'Connection closed successfully'
      rescue StandardError => e
        log :debug, "Connection not closed: #{e.message} (#{e.class})"
        nil
      end
      @session = nil
      true
    end

    # Kill the underlying connection
    def kill!
      log :debug, 'Attempting kill/shutdown of session'
      @session.shutdown!
      log :debug, 'Session shutdown success'
      @session = nil
    end

    def execute(commands, options = nil, &block)
      options = create_options(options, block)
      command_to_execute = prepare_commands(commands, options)

      # Execute the command
      response = Response.new
      response.command = command_to_execute
      connect unless connected?

      # Log the command
      log :info, "Executing: #{command_to_execute}"
      log :debug, "Timeout: #{options.timeout}"

      begin
        channel = nil
        Timeout.timeout(options.timeout) do
          channel = @session.open_channel do |ch|
            response.start_time = Time.now
            channel.exec(command_to_execute) do |_, success|
              raise "Command \"#{command_to_execute}\" was unable to execute" unless success

              ch.send_data(options.stdin) if options.stdin

              if options.file_to_stream.nil? && options.sudo_password.nil?
                log :debug, 'Sending EOF to channel'
                ch.eof!
              end

              ch.on_data do |_, data|
                response.stdout += data
                options.stdout&.call(data)
                log :debug, data.gsub(/\r/, '')
              end

              ch.on_extended_data do |_, _, data|
                response.stderr += data.delete("\r")
                options.stderr&.call(data)
                log :debug, data
                if options.sudo_password && data =~ /^\[sshake-sudo-password\]:\s\z/
                  log :debug, 'Sending sudo password'
                  ch.send_data "#{options.sudo_password}\n"

                  if options.file_to_stream.nil?
                    log :debug, 'Sending EOF after sudo password because no file'
                    ch.eof!
                  end
                end
              end

              ch.on_request('exit-status') do |_, data|
                response.exit_code = data.read_long&.to_i
                log :debug, "Exit code: #{response.exit_code}"
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
        log :debug, 'Got timeout error while executing command'
        kill!
        response.timeout!
      ensure
        response.finish_time = Time.now
      end

      handle_response(response, options)
    end

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
