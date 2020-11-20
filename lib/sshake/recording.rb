# frozen_string_literal: true

require 'sshake/recorder'
require 'sshake/recorded_session'
require 'sshake/error'

module SSHake

  class NestedRecordingsUnsupportedError < Error
  end

  class << self

    def record(name)
      if Thread.current[:sshake_recorder]
        raise NestedRecordingsUnsupportedError, 'You cannot nest SSHake.record blocks'
      end

      recorder = Recorder.new(name)
      recorder.load
      Thread.current[:sshake_recorder] = recorder
      yield
    ensure
      Thread.current[:sshake_recorder] = nil
    end

  end

end
