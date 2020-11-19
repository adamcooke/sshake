# frozen_string_literal: true

module SSHake

  class Error < StandardError
  end

  class ExecutionError < Error

    def initialize(response)
      @response = response
    end

    attr_reader :response

    def to_s
      message
    end

    def message
      "Failed to execute command: #{@response.command} " \
      "(stderr: #{@response.stderr}) (exit code: #{@response.exit_code})"
    end

  end

end
