# frozen_string_literal: true

require 'tempfile'
require 'spec_helper'
require 'sshake/recorded_session'
require 'sshake/recorder'

describe SSHake::RecordedSession do
  subject(:recorder) { SSHake::Recorder.new('example') }
  subject(:session) { SSHake::Session.new(HOST, USER, klogger: Klogger.new(:ssh, destination: '/dev/null')) }
  subject(:recorded_session) { SSHake::RecordedSession.new(recorder, session) }

  context '#execute' do
    it 'executes a remote request if nothing is in the cache' do
      response = recorded_session.execute('echo Hello!')
      expect(response).to be_a SSHake::Response
      expect(response.cached?).to be false
      expect(response.stdout).to eq "Hello!\n"
    end

    it 'pulls an item from the cache if it exists' do
      response = SSHake::Response.new(cached: true)
      response.stdout = 'Hello world!'
      response.exit_code = 0
      recorder.record('echo Hello world!', response, connection: { host: HOST, user: USER, port: 22 })

      response = recorded_session.execute('echo Hello world!')
      expect(response).to be_a SSHake::Response
      expect(response.cached?).to be true
      expect(response.stdout).to eq 'Hello world!'
    end

    it 'caches and then recalls the same command' do
      first_response = recorded_session.execute('echo Hello there!')
      expect(first_response).to be_a SSHake::Response
      expect(first_response.stdout).to eq "Hello there!\n"
      expect(first_response.cached?).to be false

      second_response = recorded_session.execute('echo Hello there!')
      expect(second_response).to be_a SSHake::Response
      expect(second_response.stdout).to eq "Hello there!\n"
      expect(second_response.cached?).to be true
    end
  end
end
