# ChefBackup::Tar class.  Used to backup Standalone and Tier Servers that aren't
# installed on LVM
module ChefBackup
# rubocop:disable IndentationWidth
class Tar < ChefBackup::Base
  # rubocop:enable IndentationWidth
  def backup
    log 'Starting Chef Server backup'
    populate_data_map
    if backend?
      stop_chef_server(except: [:keepalived, :postgresql]) unless online?
      dump_db
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

  def populate_data_map
    stateful_services.each do |service|
      next unless private_chef.key?(service)
      data_map.add_service(service, private_chef[service]['data_dir'])
    end

    config_directories.each do |config|
      data_map.add_config(config, "/etc/#{config}")
    end
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
