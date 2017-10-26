require 'fileutils'
require 'json'
require 'time'
require 'highline/import'

# rubocop:disable IndentationWidth
module ChefBackup
module Strategy
# ChefBackup::Tar class.  Used to backup Standalone and Tier Servers that aren't
# installed on LVM
class TarBackup
  # rubocop:enable IndentationWidth
  include ChefBackup::Helpers
  include ChefBackup::Exceptions

  attr_reader :backup_time

  def initialize
    @backup_time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
  end

  #
  # Ensures existence of an export directory for the backup
  #
  # @return [String] A path to the export_dir
  #
  def export_dir
    @export_dir ||= begin
      dir =
        if service_config['backup']['export_dir']
          service_config['backup']['export_dir']
        else
          msg = ["backup['export_dir'] has not been set.",
                 'defaulting to: /var/opt/chef-backups'].join(' ')
          log(msg, :warn)
          '/var/opt/chef-backups'
        end
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      dir
    end
  end

  #
  # Perform a pg_dump
  #
  # @return [TrueClass, FalseClass]
  #
  def dump_db
    return true unless pg_dump?
    if external_pg?
      log('Cannot backup external postgresql', :warn)
      return false
    end
    pg_user = service_config['postgresql']['username']
    sql_file = "#{tmp_dir}/chef_backup-#{backup_time}.sql"
    cmd = [chpst,
           "-u #{pg_user}",
           pg_dumpall,
           "> #{sql_file}"
          ].join(' ')
    log "Dumping Postgresql database to #{sql_file}"
    shell_out!(cmd, env: ["PGOPTIONS=#{pg_options}"])
    data_map.services['postgresql']['pg_dump_success'] = true
    data_map.services['postgresql']['username'] = pg_user
    true
  end

  def chpst
    "#{base_install_dir}/embedded/bin/chpst"
  end

  def pg_dumpall
    "#{base_install_dir}/embedded/bin/pg_dumpall"
  end

  def populate_data_map
    unless config_only?
      stateful_services.each do |service|
        next unless service_config.key?(service)
        data_map.add_service(service, service_config[service]['data_dir'])
      end
    end

    config_directories.each do |config|
      data_map.add_config(config, "/etc/#{config}")
    end

    populate_versions

    # Don't forget the upgrades!
    if service_config.key?('upgrades')
      data_map.add_service('upgrades', service_config['upgrades']['dir'])
    end

    add_ha_services
  end

  def populate_versions
    project_names.each do |project|
      path = File.join(addon_install_dir(project), '/version-manifest.json')
      data_map.add_version(project, version_from_manifest_file(path))
    end
  end

  def add_ha_services
    if ha? && !config_only?
      data_map.add_service('keepalived', service_config['keepalived']['dir'])
      data_map.add_ha_info('provider', service_config['ha']['provider'])
      data_map.add_ha_info('path', service_config['ha']['path'])
    end
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

  DEFAULT_STATEFUL_SERVICES = %w(rabbitmq
                                 opscode-solr4
                                 elasticsearch
                                 redis_lb
                                 postgresql
                                 bookshelf).freeze

  def stateful_services
    if service_config.key?('drbd') && service_config['drbd']['enable'] == true
      ['drbd']
    else
      DEFAULT_STATEFUL_SERVICES.select do |service|
        service_enabled?(service)
      end
    end
  end

  def config_directories
    [project_name] + enabled_addons.keys
  end

  def project_names
    ([project_name] + enabled_addons.keys).uniq
  end

  # The data_map is a working record of all of the data that is backed up.
  def data_map
    @data_map ||= ChefBackup::DataMap.new do |data|
      data.backup_time = backup_time
      data.strategy = strategy
      data.topology = topology
    end
  end

  def not_implemented
    msg = "#{caller[0].split[1]} is not implemented for this strategy"
    raise NotImplementedError, msg
  end

  def backup
    log "Starting Chef Server backup #{config_only? ? '(config only)' : ''}"
    populate_data_map
    stopped = false
    if backend? && !config_only?
      if !online?
        ask_to_go_offline unless offline_permission_granted?
        stop_chef_server(except: [:keepalived, :postgresql])
        dump_db
        stop_service(:postgresql)
        stopped = true
      else
        dump_db
      end
    end
    write_manifest
    create_tarball
    start_chef_server if stopped
    export_tarball
    cleanup
    log 'Backup Complete!'
  rescue => e
    log "Something wen't terribly wrong, aborting backup", :error
    log e.message, :error
    cleanup
    start_chef_server
    raise e
  end

  def create_tarball
    log 'Creating backup tarball'
    cmd = [
      "tar -czf #{tmp_dir}/#{export_filename}",
      data_map.services.map { |_, v| v['data_dir'] }.compact.join(' '),
      data_map.configs.map { |_, v| v['data_dir'] }.compact.join(' '),
      Dir["#{tmp_dir}/*"].map { |f| File.basename(f) }.join(' ')
    ].join(' ').strip

    res = shell_out!(cmd, cwd: tmp_dir)
    res
  end

  def export_tarball
    log "Exporting tarball to #{export_dir}"
    cmd = "rsync -chaz #{tmp_dir}/#{export_filename} #{export_dir}/"

    res = shell_out!(cmd)
    res
  end

  def export_filename
    postfix = if config_only?
                '-config'
              else
                ''
              end
    "chef-backup#{postfix}-#{backup_time}.tgz"
  end

  def service_enabled?(service)
    service_config[service] && service_config[service]['enable'] && !service_config[service]['external']
  end

  def external_pg?
    service_config['postgresql']['external']
  end

  def pg_dump?
    # defaults to true
    service_config['backup']['always_dump_db']
  end

  def offline_permission_granted?
    service_config['backup']['agree_to_go_offline']
  end

  def config_only?
    service_config['backup']['config_only']
  end

  def ask_to_go_offline
    msg = 'WARNING:  Offline backup mode must stop your Chef server before '
    msg << 'continuing.  You can skip this message by passing a "--yes" '
    msg << 'argument. Do you wish to proceed? (y/N):'

    exit(1) unless ask(msg) =~ /^y/i
  end
end
end
end
