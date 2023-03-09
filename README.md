# SSHake 🍼

SSHake is a library to help run commands on SSH servers. It's a wrapper around the net/ssh gem and provide additional functionality and simplity.

## Usage

```ruby
# Create a new session by providing the connection options.
# The same options as supported by net/ssh.
session = SSHake::Session.create("myserver.domain.com")

# Execute a command
result = session.execute('whoami') do |r|
  # Set the maximum execution time for this command.
  # If it exceeds this, the channel will be closed and will
  # reconnect to continue further commands in the session.
  # By default all commands will run for 1 minute maximum.
  r.timeout = 30

  # Specify that you wish for an exception to be raised
  # if the command experiences an error.
  r.raise_on_error

  # Specify to run the command as sudo You can optionally
  # provide the user and password (if required). If no
  # user is provided, it will be executed as root.
  r.sudo
  r.sudo password: "some password"
  r.sudo user: "mike"
  r.sudo user: "sarah", password: "sarah's password"

  # Specify data to send to stdin for this command
  r.stdin "Something to pass to STDIN"

  # Will receive any data received from stdout or stderr
  r.stdout { |result| puts result }
  r.stderr { |result| puts result }
end

# You can do things with the result as normal.
result.success?   # => Boolean
result.timeout?   # => Boolean (was this a timeout?)
result.exit_code  # => Integer
result.stdout     # => String
result.stderr     # => String

# You don't have to pass a block to `execute`. All the options can be
# passed as a hash to the execute method.
session.execute("whoami", :sudo => true, :raise_on_error => true)

# You can also pass pre-made execution options to the command.
execution_options = SSHake::ExecutionOptions.new do |r|
  r.sudo
  r.raise_on_error
end
result = session.execute("whoami", execution_options)

# The connection to the server will be established when the
# first command is executed. You can forcefully connect to the
# server by running connect.
session.connect

# You should disconnect when you're finished
session.disconnect

# You can, if you wish, provide a series of sudo passwords to
# the session which will be used whenever sudo is specified
# without a password.
session.add_sudo_password "root", "some password"

# For logging purposes, you can provide a logger to your session.
# This should be an instance of a klogger logger or a something which
# implementes its interface.
session.klogger = Klogger.new(:ssh)

# You can also set a global logger if you prefer
SSHake::Session.klogger = Klogger.new.new(:ssh, destination: "log/ssh.log")

# You can write data easily too. The 'write' method can receive
# execution options in the same way as any execute command.
session.write("/etc/example", "my example data")
```

## Installation

To install SSHake, you just need to include it in your bundle.

```ruby
gem 'sshake', '~> 1.0'
```

## Logging

SSHake uses the [Klogger](https://github.com/krystal/klogger) gem to handle structured logging of commands. You can provide your destination for these logs by providing a suitable value to the `destination` argument when initialising a logger. By default, the logger will log to STDOUT.

Note: this is a breaking change between v1 and v2 of SSHake. In v1 the logger was a simple plain Ruby logger.

## Testing

### Recording Sessions

SSHake includes support for recording SSH sessions and allowing them to be replayed in subsequent runs. This is very useful when running integration tests and you don't want to always talk to a live backend. The following example describes how to use this feature:

```ruby
# Start by requiring the recording framework
require 'sshake/recording'

# Set the path that you wish to save your recordings. This directory
# will be created if it doesn't exist.
SSHake::Recorder.save_root = '{root}/spec/recordings'

# You need to put all the work you wish to cache in a block. All sessions
# created through SSHake while within this block will be recorded or replayed
# as appropriate.
SSHake.record "name_of_set" do

  # Create a session as normal (note use of create rather than new)
  session = SSHake::Session.create('server.example.com', 'dave', port: 2345)

  # When you run commands on this session, if it has not been run before,
  # the connection to the backend host will happen as normal. The response from
  # that call will then be saved and any future command with the same command,
  # command options & connection details (host, user & port only) will be returned
  # from the cache.
  response = session.execute('whoami')

  # You can check to see whether a response has come from the cache or not
  response.cached? # => false

  # A subsequent run in the same block will also return from the cache.
  response = session.execute('whoami')
  response.cached? # => true
end
```

A few notes about this:

- YAML files containing the cached data will be saved to disk after each command is
  recorded. If you wish to clear the cache, just delete the appropriate file. Files
  are named based on the name of the block.

- You cannot nest `SSHake.record` blocks.

- If you don't specify a `save_root`, the caching will only last for the duration of
  the `record` block.

### Mocking

SSHake include a mock session object which can be used when testing to provide standard responses for commands which you wish to run.

```ruby
# Create a new mock session object session
session = SSHake::Mock::Session.new

# Add a command which is now supported by the session. Any command
# which is executed and doesn't match a command here will raise an
# error. There is no need to start or end the regext with /A or /z
# as these are implied.
session.command_set.add /useradd (\w+)/ do |response, env|
  if env.captures[0].length >= 10
    response.stderr = "error: username is too long. Must be less than 10 characters."
    response.exit_code = 1
  elsif username == 'timeout'
    response.timeout
  else
    response.stdout = "Hello #{env.captures[0]}!"
  end
end

# You can then execute this in the same way as any command
response = session.execute("useradd adam")
response.stdout #=> "Hello adam!"

# In addition to this, you can also share information between different
# commands on the same session using the environment store hash.
session.command_set.add /mkdir ([\w\/]+)/ do |response, env|
  env.store[:made_directories] ||= []
  env.store[:made_directories] << env.captures[0]
end

session.command_set.add /ls ([\w\/]+)/ do |response, env|
  if env.store[:made_directories] && env.store[:made_directories].include(env.captures[0])
    response.stdout = "file1.txt   file2.txt   file3.txt"
  else
    response.stderr = "No directory at #{env.captures[0]}"
    response.exit_code = 2
  end
end

session.execute("ls /etc/example").stderr #=> "No directory at /etc/example"
session.execute("mkdir /etc/example")
session.execute("ls /etc/example").stdout #=> "file1.txt [...]"
```
