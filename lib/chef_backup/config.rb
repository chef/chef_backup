require 'fileutils'
require 'json'

module ChefBackup
  class Config
    DEFAULT_CONFIG = {
      'backup' => {
        'always_dump_db' => true,
        'strategy' => 'none',
        'export_dir' => '/var/opt/chef-backup'
      }
    }.freeze

    class << self
      def config
        @@config ||= new
      end

      def config=(hash)
        @@config = new(hash)
      end

      def [](key)
        self.config[key]
      end

      def []=(key, value)
        self.config[key] = value
      end

      #
      # @param file [String] path to a JSON configration file
      #
      def from_json_file(file)
        path = File.expand_path(file)
        @config = new(JSON.parse(File.read(path))) if File.exist?(path)
      end
    end

    #
    # @param config [Hash] a Hash of the private-chef-running.json
    #
    def initialize(config)
      @config = DEFAULT_CONFIG.merge(config)
    end

    def [](key)
      @config[key]
    end

    def []=(key, value)
      @config[key] = value
    end
  end
end
