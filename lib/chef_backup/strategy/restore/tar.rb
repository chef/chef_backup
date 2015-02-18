require 'fileutils'
require 'pathname'
require 'forwardable'
require 'chef/mixin/deep_merge'

# rubocop:disable IndentationWidth
module ChefBackup
module Strategy
# Basic Tar Restore Strategy
class TarRestore
  # rubocop:enable IndentationWidth
  include ChefBackup::Helpers
  include ChefBackup::Exceptions
  include Chef::Mixin::DeepMerge
  extend Forwardable

  attr_accessor :tarball_path

  def_delegators :@log, :log

  def initialize(path)
    @tarball_path = path
    @log = ChefBackup::Logger.logger(private_chef['backup']['logfile'] || nil)
  end

  def restore
    log 'Restoring Chef Server from backup'
    cleanse_chef_server(config['agree_to_cleanse'])
    stop_chef_server
    restore_configs
    reconfigure_server
    update_config
    restore_services unless frontend?
    if restore_db_dump?
      start_service(:postgresql)
      import_db
    end
    start_chef_server
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
    sql_file = File.join(ChefBackup::Config['restore_dir'],
                         "chef_backup-#{manifest['backup_time']}.sql")
    ensure_file!(sql_file, InvalidDatabaseDump, "#{sql_file} not found")

    cmd = ['/opt/opscode/embedded/bin/chpst',
           "-u #{private_chef['postgresql']['username']}",
           '/opt/opscode/embedded/bin/psql',
           "-U #{private_chef['postgresql']['username']}",
           '-d opscode_chef',
           "< #{sql_file}"
          ].join(' ')
    log 'Importing Database dump'
    shell_out!(cmd)
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

  def reconfigure_server
    log 'Reconfiguring the Chef Server'
    shell_out('chef-server-ctl reconfigure')
  end

  def cleanse_chef_server(agree)
    log 'Cleaning up any old files'
    shell_out!("chef-server-ctl cleanse #{agree || ''}")
  end

  def running_config
    @running_config ||=
      JSON.parse(File.read('/etc/opscode/chef-server-running.json')) || {}
  end

  def update_config
    ChefBackup::Config.config = deep_merge(config.dup, running_config)
  end
end # Tar
end # Strategy
end # ChefBackup
