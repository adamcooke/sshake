# frozen_string_literal: true

module SSHake
  class Response
    def initialize
      @stdout = ''
      @stderr = ''
      @exit_code = 0
    end

    attr_accessor :command
    attr_accessor :stdout
    attr_accessor :stderr
    attr_accessor :exit_code
    attr_accessor :exit_signal
    attr_accessor :start_time
    attr_accessor :finish_time

    def success?
      @exit_code == 0
    end

    def time
      (finish_time - start_time).to_i
    end

    def timeout?
      @exit_code == -255
    end

    def timeout!
      @exit_code = -255
    end
  end
end
