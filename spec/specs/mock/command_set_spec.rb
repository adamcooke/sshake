# frozen_string_literal: true

require 'spec_helper'
require 'sshake/mock/command_set'

describe SSHake::Mock::CommandSet do
  subject(:command_set) { SSHake::Mock::CommandSet.new}

  it "should be able to add commands and return them" do
    command = command_set.add(/whoami/) { }
    expect(command).to be_a SSHake::Mock::Command
  end

  context "match" do
    it 'should return nil if no commands match the given command' do
      expect(command_set.match('ps')).to be nil
    end

    it 'should return the command and the matches' do
      added_command = command_set.add('ps')
      matched_command, matches = command_set.match('ps')
      expect(matched_command).to eq added_command
      expect(matches).to be_a Array
      expect(matches).to be_empty
    end
  end
end
