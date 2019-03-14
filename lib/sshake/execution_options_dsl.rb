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

    def raise_on_error
      @options.raise_on_error = true
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
  end
end
