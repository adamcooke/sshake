# frozen_string_literal: true

require 'spec_helper'
require 'sshake/mock/session'

describe SSHake::Mock::Session do
  subject(:session) { SSHake::Mock::Session.new }
  it "should have a command set" do
    expect(session.command_set).to be_a SSHake::Mock::CommandSet
  end

  it "should be able to be given a command set on initialize" do
    command_set = SSHake::Mock::CommandSet.new
    session = SSHake::Mock::Session.new(command_set: command_set)
    expect(session.command_set).to eq command_set
  end

  context '#connect' do
    it 'should raise connection timeouts' do
      session = SSHake::Mock::Session.new(:connection_error => :timeout)
      expect { session.connect }.to raise_error(Net::SSH::ConnectionTimeout)
    end

    it 'should raise authentication errors'do
      session = SSHake::Mock::Session.new(:connection_error => :authentication_failed)
      expect { session.connect }.to raise_error(Net::SSH::AuthenticationFailed)
    end

    it 'should raise connection refused errors'do
      session = SSHake::Mock::Session.new(:connection_error => :connection_refused)
      expect { session.connect }.to raise_error(Errno::ECONNREFUSED)
    end

    it 'should raise host unreachable errors' do
      session = SSHake::Mock::Session.new(:connection_error => :host_unreachable)
      expect { session.connect }.to raise_error(Errno::EHOSTUNREACH)
    end
  end

  context "connected?" do
    it 'should be false initially' do
      expect(session.connected?).to be false
    end

    it 'should be true after connect is run' do
      session.connect
      expect(session.connected?).to be true
    end

    it 'should be false after a connect and disconnect' do
      session.connect
      expect(session.connected?).to be true
      session.disconnect
      expect(session.connected?).to be false
    end
  end

  context "execute" do
    it "should raise an error when the command doesnt match anything in the set" do
      expect { session.execute('whoami') }.to raise_error SSHake::Mock::UnsupportedCommandError
    end

    it "should return a response" do
      session.command_set.add("ps") { |r| r.stdout = "12345" }
      response = session.execute('ps')
      expect(response.stdout).to eq '12345'
    end

    it "should raise an error if needed and there's an error" do
      session.command_set.add("ps") { |r| r.exit_code = 2 }
      expect { session.execute('ps', :raise_on_error => true) }.to raise_error SSHake::ExecutionError
    end

    it "should handle sudo'd commands" do
      session.command_set.add("whoami") do |r, env|
        if env.options.sudo_user
          r.stdout = env.options.sudo_user
        else
          r.stdout = "_nosudo_"
        end
      end
      expect(session.execute('whoami').stdout).to eq '_nosudo_'
      expect(session.execute('whoami', :sudo => true).stdout).to eq 'root'
      expect(session.execute('whoami', :sudo => 'dave').stdout).to eq 'dave'
    end

    it "should allow values to be shared between commands on the same session" do
      session.command_set.add(/useradd (\w+)/) do |r, env|
        env.store[:users] ||= []
        env.store[:users] << env.captures[0]
        r.stdout = "Added successfully"
      end

      session.command_set.add(/userexists (\w+)/) do |r, env|
        if env.store[:users] && env.store[:users].include?(env.captures[0])
          r.stdout = "Exists"
        else
          r.stdout = "Does not exist"
        end
      end

      expect(session.execute('userexists adam').stdout).to eq 'Does not exist'
      expect(session.execute('useradd adam').stdout).to eq 'Added successfully'
      expect(session.execute('userexists adam').stdout).to eq 'Exists'
    end

    it 'should store executed commands in an array on the session' do
      expect(session.executed_commands).to be_empty
      added_command = session.command_set.add(/useradd (\w+)/) { |r, env| r.stdout = "added: #{env.captures[0]}" }
      session.execute('useradd adam')
      expect(session.executed_commands.first).to be_a SSHake::Mock::ExecutedCommand
      expect(session.executed_commands.first.environment.command).to eq 'useradd adam'
      expect(session.executed_commands.first.environment.captures).to eq ['adam']
      expect(session.executed_commands.first.command).to eq added_command
      expect(session.executed_commands.first.response.stdout).to eq 'added: adam'
    end

    it 'should copy bytes streamed to the response' do
      begin
        file = File.open(__FILE__)

        executed_command_block = false
        added_command = session.command_set.add(/cat > \/test/) do |r, env|
          r.stdout = "added: #{env.captures[0]}"
          executed_command_block = true
          expect(env.options.file_to_stream).to eq file
       end

        response = session.execute('cat > /test', :file_to_stream => file)
        expect(response.bytes_streamed).to eq file.size
        expect(executed_command_block).to be true
      ensure
        file.close
      end
    end
  end

  context "#has_run_command?" do
    it 'should return true if any executed command matches the given regexp' do
      added_command = session.command_set.add(/useradd (\w+)/) { |r, env| r.stdout = "added: #{env.captures[0]}" }
      session.execute('useradd adam')
      expect(session.has_executed_command?('useradd adam')).to be true
    end

    it 'should return false if no execute commands match the given regexp' do
      expect(session.has_executed_command?('useradd adam')).to be false
    end
  end

  context 'find_executed_commands' do
    it 'should return an array of all executed commands matching the regexp' do
      added_command = session.command_set.add(/useradd (\w+)/) { |r, env| r.stdout = "added: #{env.captures[0]}" }
      session.execute('useradd adam')
      session.execute('useradd dave')
      expect(session.find_executed_commands(/useradd adam/).size).to eq 1
      expect(session.find_executed_commands(/useradd adam/).first).to be_a SSHake::Mock::ExecutedCommand
      expect(session.find_executed_commands(/useradd .*/).size).to eq 2
      expect(session.find_executed_commands(/useradd michael/).size).to eq 0
    end
  end

  context "#write_data" do
    it 'should allow data to be written' do
      expect(session.write_data('/etc/blah', 'Hello world!')).to be true
      expect(session.written_files['/etc/blah']).to eq 'Hello world!'
    end
  end
end
