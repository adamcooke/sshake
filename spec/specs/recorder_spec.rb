# frozen_string_literal: true

require 'spec_helper'
require 'sshake/recorder'
require 'sshake/response'
require 'sshake/execution_options'

describe SSHake::Recorder do
  subject(:recorder) { SSHake::Recorder.new(:example) }

  context '#load' do
    it 'returns nil' do
      expect(recorder.load).to be nil
    end
  end

  context '#record' do
    it 'adds the given command & options to the cache' do
      response = SSHake::Response.new
      response.stdout = "root\n"
      response.exit_code = 0
      response.start_time = Time.new(2020, 3, 1, 22)
      response.finish_time = Time.new(2020, 3, 1, 23)

      recorder.record('whoami', response)
      expect(recorder.cache['whoami']).to eq [
        connection: {},
        options: { timeout: 60 },
        response: {
          stdout: "root\n",
          stderr: '',
          exit_code: 0,
          start_time: 1_583_100_000,
          finish_time: 1_583_103_600
        }
      ]
    end
  end

  context '#play' do
    it 'returns the correct command when no options provided' do
      recorder.cache['whoami'] = [{
        connection: {},
        options: { timeout: 60 },
        response: {
          exit_code: 0,
          finish_time: 1_583_103_600,
          start_time: 1_583_100_000,
          stderr: '',
          stdout: "someuser\n"
        }
      }]

      response = recorder.play('whoami')
      expect(response).to be_a SSHake::Response
      expect(response.stdout).to eq "someuser\n"
      expect(response.exit_code).to eq 0
      expect(response.time).to eq 3600
    end

    it 'returns the correct command when no options provided' do
      recorder.cache['whoami'] = [
        {
          options: { timeout: 60, sudo_user: 'root' },
          response: {
            exit_code: 0,
            finish_time: 1_583_103_600,
            start_time: 1_583_100_000,
            stderr: '',
            stdout: "root\n"
          },
          connection: {}
        }
      ]

      response = recorder.play('whoami', options: SSHake::ExecutionOptions.from_hash(sudo: true))
      expect(response).to be_a SSHake::Response
      expect(response.stdout).to eq "root\n"
      expect(response.exit_code).to eq 0
      expect(response.time).to eq 3600
    end

    it 'returns the correct command scoped by connection' do
      recorder.cache['whoami'] = [
        {
          options: { timeout: 60 },
          response: {
            exit_code: 0,
            finish_time: 1_583_103_600,
            start_time: 1_583_100_000,
            stderr: '',
            stdout: "root\n"
          },
          connection: { hostname: 'host1', user: 'root', port: 22 }
        }
      ]

      response = recorder.play('whoami', connection: { hostname: 'host1', user: 'root', port: 22 })
      expect(response).to be_a SSHake::Response
      expect(response.stdout).to eq "root\n"
    end

    it 'returns nil when theres no match for the command' do
      expect(recorder.play('whoami')).to be nil
    end

    it 'returns nil when the options dont match' do
      recorder.cache['whoami'] = [{
        options: { timeout: 60 },
        response: {
          exit_code: 0,
          finish_time: 1_583_103_600,
          start_time: 1_583_100_000,
          stderr: '',
          stdout: "someuser\n"
        }
      }]

      expect(recorder.play('whoami', options: SSHake::ExecutionOptions.from_hash(sudo: true))).to be nil
    end

    it 'returns nil when the connection scope does not match' do
      recorder.cache['whoami'] = [
        {
          options: { timeout: 60 },
          response: {
            exit_code: 0,
            finish_time: 1_583_103_600,
            start_time: 1_583_100_000,
            stderr: '',
            stdout: "root\n"
          },
          connection: { hostname: 'host1', user: 'root', port: 22 }
        }
      ]

      response = recorder.play('whoami', connection: { hostname: 'host2', user: 'root', port: 22 })
      expect(response).to be nil
    end
  end

  context 'with a save_root set' do
    subject(:temp_root) { "/tmp/sshake-recorder-tmp-root-#{Time.now.to_i}-#{Process.pid}" }
    before { allow(SSHake::Recorder).to receive(:save_root).and_return(temp_root) }
    after { FileUtils.rm_rf(temp_root) }

    context '#load' do
      it 'loads from the file' do
        FileUtils.mkdir_p(temp_root)
        # rubocop:disable Layout/LineLength
        File.write(File.join(temp_root, 'example.yml'), "---\necho Hello again!:\n- :connection:\n    :host: \n    :user: adam\n    :port: 22\n  :options:\n    :timeout: 60\n  :response:\n    :stdout: 'Hello again!\n\n'\n    :stderr: ''\n    :exit_code: 0\n    :start_time: 1605865330\n    :finish_time: 1605865330\n")
        # rubocop:enable Layout/LineLength
        recorder.load
        expect(recorder.cache['echo Hello again!'][0]).to be_a Hash
      end
    end

    context '#record' do
      it 'saves to the save file when recording' do
        response = SSHake::Response.new
        response.stdout = "root\n"
        response.exit_code = 0
        response.start_time = Time.new(2020, 3, 1, 22)
        response.finish_time = Time.new(2020, 3, 1, 23)

        recorder.record('whoami', response)

        file_content = YAML.load_file(File.join(temp_root, 'example.yml'))
        expect(file_content).to be_a Hash
        expect(file_content['whoami']).to be_a Array
        expect(file_content['whoami'][0][:response][:stdout]).to eq "root\n"
      end
    end
  end
end
