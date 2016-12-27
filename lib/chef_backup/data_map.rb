require 'time'

module ChefBackup
  # DataMap class to store data about the data we're backing up
  class DataMap
    class << self
      def data_map
        @data_map ||= new
      end

      attr_writer :data_map
    end

    attr_accessor :strategy, :backup_time, :topology, :configs, :services, :ha, :versions

    def initialize
      @services = {}
      @configs = {}
      @versions = {}
      @ha = {}
      yield self if block_given?

      @backup_time ||= Time.now.iso8601
      @strategy ||= 'none'
      @toplogy ||= 'idontknow'
    end

    def add_service(service, data_dir)
      @services[service] ||= {}
      @services[service]['data_dir'] = data_dir
    end

    def add_config(config, path)
      @configs[config] ||= {}
      @configs[config]['data_dir'] = path
    end

    def add_version(project_name, data)
      @versions[project_name] = data
    end

    def add_ha_info(k, v)
      @ha[k] = v
    end

    def manifest
      {
        'strategy' => strategy,
        'backup_time' => backup_time,
        'topology' => topology,
        'ha' => ha,
        'services' => services,
        'configs' => configs,
        'versions' => versions
      }
    end
  end
end
