# frozen_string_literal: true

module SSHake
  module Mock
    class Environment

      def initialize(session)
        @session = session
        @captures = []
      end

      attr_accessor :command, :options, :captures

      def store
        @session&.store
      end

      def written_files
        @session&.written_files
      end

    end
  end
end
