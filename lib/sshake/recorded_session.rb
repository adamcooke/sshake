# frozen_string_literal: true

require 'sshake/base_session'
require 'sshake/recorder'
require 'sshake/session'

module SSHake
  class RecordedSession < BaseSession

    attr_reader :recorder
    attr_reader :session

    def initialize(recorder, session, **options)
      super
      @recorder = recorder
      @session = session
    end

    def execute(commands, options = nil, &block)
      options = create_options(options, block)
      command_to_execute = prepare_commands(commands, options)

      cached_response = @recorder.play(command_to_execute, options: options, connection: connection_hash)
      return cached_response if cached_response

      response = @session.execute(commands, options)
      record(command_to_execute, options, response)
      response
    end

    private

    def record(command, options, response)
      @recorder.record(command, response, options: options, connection: connection_hash)
      @recorder.save
    end

    def connection_hash
      {
        host: @session.host,
        user: @session.user,
        port: @session.port
      }
    end

  end
end
