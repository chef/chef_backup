require 'fileutils'
require 'json'
require 'time'

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
        if private_chef['backup']['export_dir']
          private_chef['backup']['export_dir']
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
    pg_user = private_chef['postgresql']['username']
    sql_file = "#{tmp_dir}/chef_backup-#{backup_time}.sql"
    cmd = ['/opt/opscode/embedded/bin/chpst',
           "-u #{pg_user}",
           '/opt/opscode/embedded/bin/pg_dumpall',
           "> #{sql_file}"
          ].join(' ')
    log "Dumping Postgresql database to #{sql_file}"
    shell_out!(cmd)
    data_map.services['postgresql']['pg_dump_success'] = true
    data_map.services['postgresql']['username'] = pg_user
    true
  end

  def populate_data_map
    stateful_services.each do |service|
      next unless private_chef.key?(service)
      data_map.add_service(service, private_chef[service]['data_dir'])
    end

    config_directories.each do |config|
      data_map.add_config(config, "/etc/#{config}")
    end

    # Don't forget the upgrades!
    if private_chef.key?('upgrades')
      data_map.add_service('upgrades', private_chef['upgrades']['dir'])
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

  def not_implemented
    msg = "#{caller[0].split[1]} is not implemented for this strategy"
    fail NotImplementedError, msg
  end

  def backup
    log 'Starting Chef Server backup'
    populate_data_map
    if backend?
      stop_chef_server(except: [:keepalived, :postgresql]) unless online?
      dump_db
      stop_service(:postgresql) unless online?
    end
    write_manifest
    create_tarball
    start_chef_server if backend? && !online?
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
      "tar -czf #{tmp_dir}/chef-backup-#{backup_time}.tgz",
      data_map.services.map { |_, v| v['data_dir'] }.compact.join(' '),
      data_map.configs.map { |_, v| v['data_dir'] }.compact.join(' '),
      Dir["#{tmp_dir}/*"].map { |f| File.basename(f) }.join(' ')
    ].join(' ').strip

    res = shell_out(cmd, cwd: tmp_dir)
    res
  end

  def export_tarball
    log "Exporting tarball to #{export_dir}"
    cmd = "rsync -chaz #{tmp_dir}/chef-backup-#{backup_time}.tgz #{export_dir}/"

    res = shell_out(cmd)
    res
  end
end
end
end
