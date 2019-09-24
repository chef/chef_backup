require "fileutils"
require "json"
require "forwardable"

module ChefBackup
  # ChefBackup Global Config
  class Config
    extend Forwardable

    DEFAULT_BASE = "private_chef".freeze
    DEFAULT_CONFIG = {
      "backup" => {
        "always_dump_db" => true,
        "strategy" => "none",
        "export_dir" => "/var/opt/chef-backup",
        "project_name" => "opscode",
        "ctl-command" => "chef-server-ctl",
        "running_filepath" => "/etc/opscode/chef-server-running.json",
        "database_name" => "opscode_chef",
      },
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
      config["config_base"] ||= DEFAULT_BASE
      base = config["config_base"]
      config[base] ||= {}
      config[base]["backup"] ||= {}
      config[base]["backup"] = DEFAULT_CONFIG["backup"].merge(config[base]["backup"])
      @config = config
    end

    def to_hash
      @config
    end

    def_delegators :@config, :[], :[]=
  end
end
