require 'fileutils'
require 'json'
require 'time'
require 'chef_backup/logger'

module ChefBackup
# rubocop:disable IndentationWidth
class Base
  # rubocop:enable IndentationWidth
  include ChefBackup::Helpers

  attr_reader :private_chef, :sv_path, :base_path, :backup_time

  # @param running_config [Hash] A hash of the private-chef-running.json
  def initialize(running_config)
    @private_chef = DEFAULT_CONFIG.merge(running_config['private_chef'])
    @base_path = '/opt/opscode'
    @sv_path = "#{base_path}/sv"
    @backup_time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
    @log ||= ChefBackup::Logger.logger(private_chef['backup']['logfile'] || nil)
  end

  def backup
    not_implemented
  end

  def log(msg, level = :info)
    @log.log(msg, level)
  end

  def export_dir
    @export_dir ||= begin
      dir =
        if private_chef['backup']['export_dir']
          private_chef['backup']['export_dir']
        else
          log(["backup['export_dir'] has not been set.",
               'defaulting to: /var/opt/chef-backups'].join(' '),
             :warn
             )
          '/var/opt/chef-backups'
        end
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      dir
    end
  end

  def dump_db
    return false unless pg_dump?
    sql_file = "#{tmp_dir}/chef_backup-#{backup_time}.sql"
    cmd = ['/opt/opscode/embedded/bin/chpst',
           "-u #{private_chef['postgresql']['username']}",
           '/opt/opscode/embedded/bin/pg_dumpall',
           "> #{sql_file}"
          ].join(' ')
    log "Dumping Postgresql database to #{sql_file}"
    res = shell_out!(cmd)
    data_map.services['postgresql']['pg_dump_success'] = true
    res
  end

  def manifest
    data_map.manifest
  end

  def write_manifest
    log 'Writing backup manifest'
    File.open("#{tmp_dir}/manifest.json", 'w') do |file|
      file.write(JSON.pretty_generate(manifest))
    end
  end

  def stateful_services
    if private_chef.key?('drbd') && private_chef['drbd']['enable'] == true
      ['drbd']
    else
      %w(
        rabbitmq
        opscode-solr4
        redis_lb
        postgresql
        bookshelf
      )
    end
  end

  def config_directories
    %w(opscode) + enabled_addons
  end

  # The data_map is a working record of all of the data that is backed up.
  def data_map
    @data_map ||= ChefBackup::DataMap.new do |data|
      data.backup_time = backup_time
      data.strategy = strategy
    end
  end

  private

  def not_implemented
    msg = "#{caller[0].split[1]} is not implemented for this strategy"
    fail NotImplementedError, msg
  end
end
end
