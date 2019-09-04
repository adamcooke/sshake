require 'sshake/response'

module SSHake
  module Mock
    class Command

      def initialize(matcher, &block)
        @matcher = matcher
        @block = block
      end

      def match(command)
        command = command.to_s
        case @matcher
        when String
          @matcher == command ? [] : nil
        when Regexp
          if match = command.match(/\A#{@matcher}\z/)
            match.captures
          end
        end
      end

      def make_response(environment)
        response = SSHake::Response.new
        response.start_time = Time.now
        if @block
          @block.call(response, environment)
        end
        response.finish_time = Time.now
        response
      end

    end
  end
end
