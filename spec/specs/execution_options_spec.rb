require 'spec_helper'
require 'sshake/execution_options'

describe SSHake::ExecutionOptions do
  subject(:options) { SSHake::ExecutionOptions.new }

  context '#timeout' do
    it 'should return the default timeout' do
      expect(options.timeout).to eq 60
    end

    it 'should have its own timeout' do
      options.timeout = 30
      expect(options.timeout).to eq 30
    end
  end

  context '.from_hash' do
    it 'should use root when sudo is true' do
      options = SSHake::ExecutionOptions.from_hash(
        sudo: true
      )
      expect(options.sudo_user).to eq 'root'
      expect(options.sudo_password).to be nil
    end

    it 'should allow sudo users and passwords to be provided' do
      options = SSHake::ExecutionOptions.from_hash(
        sudo: { user: 'dave', password: 'llama' }
      )
      expect(options.sudo_user).to eq 'dave'
      expect(options.sudo_password).to eq 'llama'
    end

    it 'should allow timeouts provided' do
      options = SSHake::ExecutionOptions.from_hash(
        timeout: 35
      )
      expect(options.timeout).to eq 35
    end

    it 'should allow raise on error to be provided' do
      options = SSHake::ExecutionOptions.from_hash(
        raise_on_error: true
      )
      expect(options.raise_on_error).to be true
    end

    it 'should allow stdin to be provided' do
      options = SSHake::ExecutionOptions.from_hash(
        stdin: 'hello'
      )
      expect(options.stdin).to eq 'hello'
    end

    it 'should allow stdout to be provided' do
      block = proc { 1 }
      options = SSHake::ExecutionOptions.from_hash(
        stdout: block
      )
      expect(options.stdout).to eq block
    end

    it 'should allow stderr to be provided' do
      block = proc { 1 }
      options = SSHake::ExecutionOptions.from_hash(
        stderr: block
      )
      expect(options.stderr).to eq block
    end
  end

  context '.from_block' do
    it 'should use root when sudo is true' do
      options = SSHake::ExecutionOptions.from_block(&:sudo)
      expect(options.sudo_user).to eq 'root'
      expect(options.sudo_password).to be nil
    end

    it 'should allow sudo users and passwords to be provided' do
      options = SSHake::ExecutionOptions.from_block do |r|
        r.sudo user: 'dave', password: 'llama'
      end
      expect(options.sudo_user).to eq 'dave'
      expect(options.sudo_password).to eq 'llama'
    end

    it 'should allow timeouts provided' do
      options = SSHake::ExecutionOptions.from_block do |r|
        r.timeout 35
      end
      expect(options.timeout).to eq 35
    end

    it 'should allow raise on error to be provided' do
      options = SSHake::ExecutionOptions.from_block(&:raise_on_error)
      expect(options.raise_on_error).to be true
    end

    it 'should allow stdin to be provided' do
      options = SSHake::ExecutionOptions.from_block do |r|
        r.stdin 'hello'
      end
      expect(options.stdin).to eq 'hello'
    end

    it 'should allow stdout to be provided' do
      options = SSHake::ExecutionOptions.from_block do |r|
        r.stdout { 1 }
      end
      expect(options.stdout).to be_a Proc
    end

    it 'should allow stderr to be provided' do
      options = SSHake::ExecutionOptions.from_block do |r|
        r.stderr { 1 }
      end
      expect(options.stderr).to be_a Proc
    end
  end
end
