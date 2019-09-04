module SSHake
  module Mock
    class Environment

      def initialize(session)
        @session = session
        @captures = []
      end

      attr_accessor :command
      attr_accessor :captures

      def store
        @session ? @session.store : nil
      end

      def written_files
        @session ? @session.written_files : nil
      end

    end
  end
end
