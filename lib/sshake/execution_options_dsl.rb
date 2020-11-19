# frozen_string_literal: true

module SSHake
  class ExecutionOptionsDSL

    def initialize(options)
      @options = options
    end

    def timeout(timeout)
      @options.timeout = timeout
    end

    def sudo(options = {})
      @options.sudo_user = options[:user] || 'root'
      @options.sudo_password = options[:password]
    end

    # rubocop:disable Style/OptionalBooleanParameter
    def raise_on_error(bool = true)
      @options.raise_on_error = bool
    end
    # rubocop:enable Style/OptionalBooleanParameter

    def dont_raise_on_error
      @options.raise_on_error = false
    end

    def stdin(value)
      @options.stdin = value
    end

    def stdout(&block)
      @options.stdout = block
    end

    def stderr(&block)
      @options.stderr = block
    end

    def file_to_stream(file)
      @options.file_to_stream = file
    end

  end
end
