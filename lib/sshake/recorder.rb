# frozen_string_literal: true

require 'yaml'
module SSHake
  class Recorder

    class << self

      # Return the root where all recorded sessions should be stored
      #
      # @return [nil, String]
      attr_accessor :save_root

    end

    attr_reader :name
    attr_reader :cache

    def initialize(name, cache: nil)
      @name = name
      @cache = cache || {}
    end

    def load
      return if self.class.save_root.nil?

      @cache = YAML.load_file(File.join(self.class.save_root, "#{name}.yml"))
    end

    def save
      return if self.class.save_root.nil?

      FileUtils.mkdir_p(self.class.save_root)
      File.write(File.join(self.class.save_root, "#{name}.yml"), @cache.to_yaml)
    end

    def play(command, connection: {}, options: nil)
      possibilities = @cache[command]
      return nil if possibilities.nil?

      options_as_hash = options_to_hash(options)

      possibility = possibilities.find do |p|
        p[:options] == options_as_hash &&
          p[:connection] == connection
      end

      return nil if possibility.nil?

      response = Response.new(cached: true)
      possibility[:response].each do |key, value|
        response.public_send("#{key}=", value)
      end
      response
    end

    def record(command, response, connection: {}, options: nil)
      @cache[command] ||= []
      @cache[command] << {
        connection: connection,
        options: options_to_hash(options),
        response: response_to_hash(response)
      }
      save
    end

    private

    def response_to_hash(response)
      {
        stdout: response.stdout,
        stderr: response.stderr,
        exit_code: response.exit_code,
        start_time: response.start_time.to_i,
        finish_time: response.finish_time.to_i
      }
    end

    def options_to_hash(options)
      options = ExecutionOptions.from_hash({}) if options.nil?

      hash = {}
      hash[:timeout] = options.timeout if options.timeout
      hash[:sudo_user] = options.sudo_user if options.sudo_user
      hash[:sudo_password] = options.sudo_password if options.sudo_password
      hash[:raise_on_error] = true if options.raise_on_error?
      hash[:stdin] = Digest::SHA1.hexdigest(options.stdin) if options.stdin
      hash[:file_to_stream] = Digest::SHA1.hexdigest(options.file_to_stream.read) if options.file_to_stream

      hash
    end

  end
end
