# frozen_string_literal: true

require 'spec_helper'
require 'sshake/recording'
require 'sshake/session'

describe SSHake do
  context '.record' do
    it 'executes the given block' do
      called = false
      SSHake.record('example') { called = true }
      expect(called).to be true
    end

    it 'raises an error if another recorder is set up' do
      expect do
        SSHake.record('example') { SSHake.record('example2') { true } }
      end.to raise_error SSHake::NestedRecordingsUnsupportedError
    end
  end

  context 'Session.create' do
    it 'returns a recorded session when invoked within a record block' do
      SSHake.record('example') do
        session = SSHake::Session.create(HOST)
        expect(session).to be_a SSHake::RecordedSession
        expect(session.session).to be_a SSHake::Session
      end
    end

    it 'returns a normal session when invoked outside of a record block' do
      expect(SSHake::Session.create(HOST)).to be_a SSHake::Session
    end
  end
end
