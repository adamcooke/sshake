# frozen_string_literal: true

module SSHake
  class Error < StandardError
  end

  class ExecutionError < Error
    def initialize(response)
      response
    end

    attr_reader :response

    def message
      "Failed to execute command: #{@response.command} (exit code: #{@response.exit_code})"
    end
  end
end
