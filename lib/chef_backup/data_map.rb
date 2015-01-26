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

    attr_accessor :strategy, :backup_time, :configs, :services

    def initialize
      @services = {}
      @configs = {}
      yield self if block_given?

      @backup_time ||= Time.now.iso8601
      @strategy ||= 'none'
    end

    def add_service(service, data_dir)
      @services[service] ||= {}
      @services[service]['data_dir'] = data_dir
    end

    def add_config(config, path)
      @configs[config] ||= {}
      @configs[config]['data_dir'] = path
    end

    def manifest
      {
        'strategy' => strategy,
        'backup_time' => backup_time,
        'services' => services,
        'configs' => configs
      }
    end
  end
end
