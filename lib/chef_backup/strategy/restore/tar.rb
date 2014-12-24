require 'fileutils'
require 'pathname'

module ChefBackup
module Strategy
# rubocop:disable IndentationWidth
class TarRestore
  # rubocop:enable IndentationWidth
  include ChefBackup::Helpers

  attr_accessor :tarball_path

  def initialize(path, config)
    @tarball_path = path
    @log = ChefBackup::Logger.logger(private_chef['backup']['logfile'] || nil)
  end

  def log(msg, level = :info)
    @log.log(msg, level)
  end

  def restore
    unpack_tarball
    stop_chef_server
    restore_services unless frontend?
    restore_configs
    if restore_db_dump?
      start_service(:postgresql)
      import_db
    end
    reconfigure_server
    start_chef_server
    cleanup
    log "Restoration Completed!"
  end

  def unpack_tarball
    ensure_file!(tarball_path, InvalidTarball, "#{tarball_path} not found")
    log "Expanding tarball: #{tarball_path}"
    shell_out!("tar zxf #{tarball_path} -C #{restore_directory}")
  end

  def manifest
    @manifest ||= begin
      manifest = File.expand_path(File.join(restore_directory, 'manifest.json'))
      ensure_file!(manifest, InvalidManifest, "#{manifest} not found")
      JSON.parse(File.read(manifest))
    end
  end

  def restore_db_dump?
    if manifest.key?('services')
      manifest['services']['postgresql']['pg_dump_success'] && !frontend?
    else
      false
    end
  rescue NoMethodError
    false
  end

  def import_db
    if frontend?
      log('Skipping DB dump import on FE', :warn)
      return true
    end

    sql_file = File.join(restore_directory,
                         "chef_backup-#{manifest['backup_time']}.sql")
    ensure_file!(sql_file, InvalidDatabaseDump, "#{sql_file} not found")

    cmd = ['/opt/opscode/embedded/bin/chpst',
           "-u #{private_chef['postgresql']['username']}",
           '/opt/opscode/embedded/bin/psql',
           "-U #{private_chef['postgresql']['username']}",
           '-d opscode_chef',
           "< #{sql_file}"
          ].join(' ')
    log "Importing Database dump"
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
    source = File.expand_path(File.join(restore_directory,
                                        manifest[type.to_s][name]['data_dir']))
    destination = manifest[type.to_s][name]['data_dir']
    FileUtils.mkdir_p(destination) unless File.directory?(destination)
    cmd = "rsync -chaz --delete #{source}/ #{destination}"
    log "Restoring the #{name} data"
    shell_out!(cmd)
  end

  def ensure_file!(file, exception, message)
    File.exists?(file) ? true : fail(exception, message)
  end

  def backup_name
    @backup_name ||= Pathname.new(tarball_path).basename.sub_ext('').to_s
  end

  def restore_directory
    @restore_directory ||= begin
      dir_name = File.join(tmp_dir, backup_name)
      # clean restore directory if it exists
      if File.directory?(dir_name)
        FileUtils.rm_r(Dir.glob("#{dir_name}/*"))
      else
        FileUtils.mkdir_p(dir_name)
      end
      dir_name
    end
  end

  def reconfigure_server
    log "Reconfiguring the Chef Server"
    shell_out("chef-server-ctl reconfigure")
  end
end # ChefBackup::Tar
end # ChefBackup
end
