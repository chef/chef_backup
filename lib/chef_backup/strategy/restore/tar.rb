require 'fileutils'
require 'pathname'
require 'forwardable'
require 'chef_backup/deep_merge'

# rubocop:disable IndentationWidth
module ChefBackup
module Strategy
# Basic Tar Restore Strategy
class TarRestore
  # rubocop:enable IndentationWidth
  include ChefBackup::Helpers
  include ChefBackup::Exceptions
  include ChefBackup::Mixin::DeepMerge
  extend Forwardable

  attr_accessor :tarball_path
  attr_writer :manifest

  def_delegators :@log, :log

  def initialize(path)
    @tarball_path = path
    @log = ChefBackup::Logger.logger(service_config['backup']['logfile'] || nil)
  end

  def restore
    log 'Restoring Chef Server from backup'
    return unless check_manifest_version
    cleanse_chef_server(config['agree_to_cleanse'])
    if ha?
      log 'Performing HA restore - please ensure that keepalived is not running on the standby host'
      fix_ha_plugins
      check_ha_volume
      touch_drbd_ready
    end
    restore_configs
    restore_services unless frontend?
    touch_sentinel
    reconfigure_marketplace if marketplace?
    reconfigure_server
    update_config
    import_db if restore_db_dump?
    start_chef_server
    reconfigure_add_ons
    restart_add_ons
    cleanup
    log 'Restoration Completed!'
  end

  def manifest
    @manifest ||= begin
      manifest = File.expand_path(File.join(ChefBackup::Config['restore_dir'],
                                            'manifest.json'))
      ensure_file!(manifest, InvalidManifest, "#{manifest} not found")
      JSON.parse(File.read(manifest))
    end
  end

  def restore_db_dump?
    manifest['services']['postgresql']['pg_dump_success'] && !frontend?
  rescue NoMethodError
    false
  end

  def import_db
    start_service('postgresql')
    sql_file = File.join(ChefBackup::Config['restore_dir'],
                         "chef_backup-#{manifest['backup_time']}.sql")
    ensure_file!(sql_file, InvalidDatabaseDump, "#{sql_file} not found")

    cmd = [chpst,
           "-u #{manifest['services']['postgresql']['username']}",
           pgsql,
           "-U #{manifest['services']['postgresql']['username']}",
           "-d #{database_name}",
           "< #{sql_file}"
          ].join(' ')
    log 'Importing Database dump'
    shell_out!(cmd, env: ["PGOPTIONS=#{pg_options}"])
  end

  def restore_services
    manifest.key?('services') && manifest['services'].keys.each do |service|
      restore_data(:services, service)
    end
  end

  def restore_configs
    manifest.key?('configs') && manifest['configs'].keys.each do |config|
      restore_data(:configs, config)
    end
  end

  def touch_sentinel
    dir = '/var/opt/opscode'
    sentinel = File.join(dir, 'bootstrapped')
    FileUtils.mkdir_p(dir) unless File.directory?(dir)
    File.open(sentinel, 'w') { |file| file.write 'bootstrapped!' }
  end

  def restore_data(type, name)
    source = File.expand_path(File.join(config['restore_dir'],
                                        manifest[type.to_s][name]['data_dir']))
    destination = manifest[type.to_s][name]['data_dir']
    FileUtils.mkdir_p(destination) unless File.directory?(destination)
    cmd = "rsync -chaz --delete #{source}/ #{destination}"
    log "Restoring the #{name} data"
    shell_out!(cmd)
  end

  def backup_name
    @backup_name ||= Pathname.new(tarball_path).basename.sub_ext('').to_s
  end

  def check_manifest_version
    unless manifest['versions']
      log 'no version information in manifest'
      return true
    end

    manifest['versions'].each_pair do |name, data|
      installed = version_from_manifest_file(data['path'])

      if installed == :no_version
        log "Warning: #{name} @ #{data['version']} not installed"
      elsif installed['version'] != data['version']
        log "package #{name} #{installed['version']} installed, but backup was"\
            " from #{data['version']}. Please install correct version, restore, then upgrade."
        return false
      end
    end
    true
  end

  def fix_ha_plugins
    log 'Fixing HA plugins directory (https://github.com/chef/chef-server/issues/115)'
    plugins_dir = '/var/opt/opscode/plugins'
    drbd_plugin = File.join(plugins_dir, 'chef-ha-drbd.rb')

    FileUtils.mkdir_p(plugins_dir) unless Dir.exist?(plugins_dir)
    FileUtils.ln_sf('/opt/opscode/chef-server-plugin.rb', drbd_plugin) unless
      File.exist?(drbd_plugin)
  end

  def check_ha_volume
    log 'Checking that the HA storage volume is mounted'
    ha_data_dir = manifest['ha']['path']

    unless ha_data_dir_mounted?(ha_data_dir)
      raise "Please mount the data directory #{ha_data_dir} and perform any DRBD configuration before continuing"
    end
  end

  def ha_data_dir_mounted?(ha_data_dir)
    File.read('/proc/mounts').split("\n").grep(/#{ha_data_dir}/).count > 0
  end

  def touch_drbd_ready
    log 'Touching drbd_ready file'
    FileUtils.touch('/var/opt/opscode/drbd/drbd_ready') unless
      File.exist?('/var/opt/opscode/drbd/drbd_ready')
  end

  def reconfigure_server
    log 'Reconfiguring the Chef Server'
    shell_out("#{ctl_command} reconfigure")
  end

  def cleanse_chef_server(agree)
    log 'Cleaning up any old files'
    # The chef-server-ctl cleanse command deliberately waits 60 seconds to give
    # you an option to cancel it.  Therefore, don't count it in the timeout that
    # the user provided.  If the user has eagerly dismissed that wait period,
    # then don't elongate the timeout.  The user can do this with the -c flag.
    timeout = shell_timeout + (agree ? 0 : 60) if shell_timeout
    shell_out!("#{ctl_command} cleanse #{agree || ''}", 'timeout' => timeout)
  end

  def running_config
    @running_config ||=
      JSON.parse(File.read(running_filepath)) || {}
  end

  def update_config
    ChefBackup::Config.config = deep_merge(config.dup, running_config)
  end
end # Tar
end # Strategy
end # ChefBackup
