# frozen_string_literal: true

require 'spec_helper'
require 'sshake/session'

describe SSHake::Session do
  subject(:session) { SSHake::Session.new(HOST, USER) }

  context '#connect' do
    it 'should connect' do
      expect(session.connect).to be true
      expect(session.session).to be_a(Net::SSH::Connection::Session)
    end
  end

  context '#connected?' do
    it 'should be false when not connected' do
      expect(session.connected?).to be false
    end

    it 'should be true when connected' do
      session.connect
      expect(session.connected?).to be true
    end
  end

  context '#disconnect' do
    it 'should disconnect' do
      session.connect
      expect(session.disconnect).to be true
    end
  end

  context '#execute' do
    it 'should work with a simple command' do
      response = session.execute('whoami')
      expect(response).to be_a(SSHake::Response)
      expect(response.exit_code).to eq 0
      expect(response.stdout).to eq "#{USER}\n"
    end

    it 'should receive options in block form' do
      stdout_block = []
      session.execute('whoami') do |r|
        r.stdout { |data| stdout_block << data }
      end
      expect(stdout_block).to include("#{USER}\n")
    end

    it 'should receive options in hash form' do
      stdout_block = []
      session.execute('whoami', stdout: proc { |data| stdout_block << data })
      expect(stdout_block).to include("#{USER}\n")
    end

    it 'should timeout when timing out' do
      response = session.execute('sleep 7', timeout: 2)
      expect(response.time).to be < 3
      expect(response.timeout?).to be true
      expect(response.exit_code).to eq -255
    end

    it 'should not hang closing connections when timed out' do
      start_time = Time.now
      response = session.execute('sleep 7', timeout: 2)
      session.disconnect
      total_time = (Time.now - start_time).to_i
      expect(total_time).to be < 3
      expect(response.timeout?).to be true
      expect(response.exit_code).to eq -255
    end

    it 'should automatically establish a new connection after being killed' do
      session.execute('whoami')
      session.kill!
      response = session.execute('whoami')
      expect(response.success?).to be true
    end

    it 'should raise an error if that is what is required' do
      expect do
        session.execute('exit 1', raise_on_error: true)
      end.to raise_error(SSHake::ExecutionError) do |e|
        expect(e.message).to include "(exit code: 1)"
        expect(e.message).to include "exit 1"
        expect(e.message).to include "(stderr: )"
      end
    end

    it 'should raise an error if the session is set to raise errors' do
      session.raise_on_error = true
      expect do
        session.execute('exit 1')
      end.to raise_error(SSHake::ExecutionError)
    end

    it 'should not raise an error if the session is set to raise errors but the command is not' do
      session.raise_on_error = true
      expect do
        session.execute('exit 1', raise_on_error: false)
      end.to_not raise_error
    end

    it 'should not raise an error if the session is set to raise errors but the command is not with block' do
      session.raise_on_error = true
      expect do
        session.execute('exit 1') do |r|
          r.raise_on_error false
        end
      end.to_not raise_error
    end

    it 'should not be successful if not successful' do
      expect do
        result = session.execute('exit 1')
        expect(result.success?).to be false
      end.to_not raise_error
    end

    it 'should allow files to be streamed to the remote' do
      session.execute('rm -rf /tmp/stream-test.txt')
      result = session.execute('cat > /tmp/stream-test.txt', :file_to_stream => File.new(__FILE__))
      expect(result.bytes_streamed).to eq File.size(__FILE__)
      expect(session.execute('cat /tmp/stream-test.txt').stdout).to eq File.read(__FILE__)
    end
  end

  context '#write_data' do
    it 'should upload files' do
      data = "Hello world! #{SecureRandom.uuid}"
      result = session.write_data('/tmp/sshaketestfile', data)
      expect(result).to be true
      read = session.execute('cat /tmp/sshaketestfile')
      expect(read.stdout).to eq data
    end
  end

  context 'logging' do
    it 'should log output' do
      string_io = StringIO.new
      session.logger = Logger.new(string_io)
      session.execute('whoami')
      string_io.rewind
      output = string_io.read
      expect(output).to match /\[#{session.id}\] \[#{HOST}\] Executing: whoami/
      expect(output).to match /\[#{session.id}\] \[#{HOST}\] #{USER}/
      expect(output).to match /\[#{session.id}\] \[#{HOST}\] Exit code: 0/
    end
  end
end
