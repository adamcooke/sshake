# frozen_string_literal: true

require 'sshake/execution_options_dsl'

module SSHake
  class ExecutionOptions

    # The timeout
    #
    # @return [Integer]
    def timeout
      @timeout || self.class.default_timeout
    end
    attr_writer :timeout

    # The user to execute sudo commands as. If nil, commands will
    # not be executed with sudo.
    #
    # @return [String]
    attr_accessor :sudo_user

    # The password to be provided to the interactive sudo prompt
    #
    # @return [String]
    attr_accessor :sudo_password

    # Should errors be raised?
    #
    # @return [Boolean]
    attr_accessor :raise_on_error

    # The data to pass to stdin when executing this command
    #
    # @return [String]
    attr_accessor :stdin

    # A proc to call whenever data is received on stdout
    #
    # @return [Proc]
    attr_accessor :stdout

    # A proc to call whenever data is received on stderr
    #
    # @return [Proc]
    attr_accessor :stderr

    # A file that you wish to stream to the remote channel
    # with the current commend
    #
    # @return [File]
    attr_accessor :file_to_stream

    # Should errors be raised
    #
    # @return [Boolean]
    def raise_on_error?
      !!@raise_on_error
    end

    class << self

      # Return the default timeout
      #
      # @return [Integer]
      def default_timeout
        @default_timeout || 60
      end
      attr_writer :default_timeout

      # Create a new set of options from a given hash
      #
      # @param [Hash] hash
      # @return [SSHake::ExecutionOptions]
      def from_hash(hash)
        options = new
        options.timeout = hash[:timeout]
        case hash[:sudo]
        when String
          options.sudo_user = hash[:sudo]
        when Hash
          options.sudo_user = hash[:sudo][:user]
          options.sudo_password = hash[:sudo][:password]
        when true
          options.sudo_user = 'root'
        end
        # rubocop:disable Style/DoubleNegation
        options.raise_on_error = !!hash[:raise_on_error]
        # rubocop:enable Style/DoubleNegation
        options.stdin = hash[:stdin]
        options.stdout = hash[:stdout]
        options.stderr = hash[:stderr]
        options.file_to_stream = hash[:file_to_stream]
        options
      end

      # Create a new set of options from a block
      #
      # @return [SSHake::ExecutionOptions]
      def from_block
        options = new
        dsl = ExecutionOptionsDSL.new(options)
        yield dsl
        options
      end

    end

  end
end
