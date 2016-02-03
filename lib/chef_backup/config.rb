require 'fileutils'
require 'json'
require 'forwardable'

module ChefBackup
  # ChefBackup Global Config
  class Config
    extend Forwardable

    DEFAULT_CONFIG = {
      'backup' => {
        'config_only' => false,
        'always_dump_db' => true,
        'strategy' => 'none',
        'export_dir' => '/var/opt/chef-backup'
      }
    }.freeze

    class << self
      def config
        @config ||= new
      end

      def config=(hash)
        @config = new(hash)
      end

      def [](key)
        config[key]
      end

      def []=(key, value)
        config[key] = value
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
    def initialize(config = {})
      config['private_chef'] ||= {}
      config['private_chef']['backup'] ||= {}
      config['private_chef']['backup'] =
        DEFAULT_CONFIG['backup'].merge(config['private_chef']['backup'])
      @config = config
    end

    def_delegators :@config, :[], :[]=
  end
end
