# frozen_string_literal: true

require 'spec_helper'
require 'sshake/mock/command'

describe SSHake::Mock::Command do
  context '#match' do
    it 'should be able to match strings' do
      command = SSHake::Mock::Command.new('whoami')
      expect(command.match('whoami')).to be_a Array
      expect(command.match('other')).to be_nil
    end

    it 'should be able to match regular expressions' do
      command = SSHake::Mock::Command.new(/whoami/)
      expect(command.match('whoami')).to be_a Array
      expect(command.match('other')).to be_nil
    end

    it 'should be able to match regular expressions with capture groups' do
      command = SSHake::Mock::Command.new(/useradd (\w+) -g (\w+)/)
      match = command.match('useradd adam -g users')
      expect(match[0]).to eq 'adam'
      expect(match[1]).to eq 'users'
    end
  end

  context '#make_response' do
    it 'should return a response' do
      command = SSHake::Mock::Command.new(/useradd (\w+)/) do |r, env|
        r.stdout = env.command
        r.stderr = "hello #{env.captures[0]}"
      end

      env = SSHake::Mock::Environment.new(nil)
      env.command = 'useradd adam'
      env.captures = ['adam']

      response = command.make_response(env)
      expect(response.stdout).to eq 'useradd adam'
      expect(response.stderr).to eq 'hello adam'
    end
  end
end
