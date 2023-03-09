# frozen_string_literal: true

module SSHake

  class << self

    def klogger
      @klogger ||= Klogger.new(:ssh, destination: $stdout, formatter: :go)
    end
    attr_writer :klogger

  end

end
