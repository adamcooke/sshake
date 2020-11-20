# frozen_string_literal: true

module SSHake
  class Response

    def initialize(cached: false)
      @stdout = ''
      @stderr = ''
      @exit_code = 0
      @bytes_streamed = 0
      @cached = cached
    end

    attr_accessor :command, :stdout, :stderr, :exit_code, :exit_signal, :start_time, :finish_time, :bytes_streamed

    def success?
      @exit_code.zero?
    end

    def cached?
      @cached == true
    end

    def cached!
      @cached = true
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
