require 'mixlib/shellout'

# Some of these are ported from omnibus-ctl
module ChefBackup::Helpers
  def integer?(string)
    Integer(string)
  rescue ArgumentError
    false
  end

  def private_chef
    ChefBackup::Config.config['private_chef']
  end

  def log(message, level = :info)
    ChefBackup::Logger.logger.log(message, level)
  end

  def shell_out(*command)
    cmd = Mixlib::ShellOut.new(*command)
    cmd.live_stream ||= $stdout.tty? ? $stdout : nil
    cmd.run_command
    cmd
  end

  def shell_out!(*command)
    cmd = shell_out(*command)
    cmd.error!
    cmd
  end

  def all_services
    Dir['/opt/opscode/sv/*'].map { |f| File.basename(f) }.sort
  end

  def enabled_services
    all_services.select { |sv| service_enabled?(sv) }
  end

  def disabled_services
    all_services.select { |sv| !service_enabled?(sv) }
  end

  def service_enabled?(service)
    File.symlink?("/opt/opscode/service/#{service}")
  end

  def stop_service(service)
    res = shell_out("chef-server-ctl stop #{service}")
    res
  end

  def start_service(service)
    res = shell_out("chef-server-ctl start #{service}")
    res
  end

  def stop_chef_server(params = {})
    log 'Bringing down the Chef Server'
    services = enabled_services
    services -= params[:except].map(&:to_s) if params.key?(:except)
    services.each { |sv| stop_service(sv) }
  end

  def start_chef_server
    log 'Bringing up the Chef Server'
    enabled_services.each { |sv| start_service(sv) }
  end

  def enabled_addons
    @enabled_addons ||= %w(
      opscode-manage
      opscode-reporting
      opscode-push-jobs-server
      opscode-analytics
      chef-ha
      chef-sync
    ).select { |service| addon?(service) }
  end

  def addon?(service)
    File.directory?("/etc/#{service}")
  end

  def pg_dump?
    if frontend? # don't dump postgres on frontends
      false
    elsif private_chef['backup']['always_dump_db'] == true # defaults to true
      true
    elsif strategy !~ /lvm|ebs/ && backend? # backup non-block device backends
      true
    else
      false # if we made it here then we're on lvm/ebs and overrode defaults
    end
  end

  def strategy
    private_chef['backup']['strategy']
  end

  def frontend?
    private_chef['role'] == 'frontend'
  end

  def backend?
    private_chef['role'] =~  /backend|standalone/
  end

  def online?
    private_chef['backup']['mode'] == 'online'
  end

  def tmp_dir
    ChefBackup::Config['tmp_dir'] ||= begin
      if private_chef['backup'].key?('tmp_dir') &&
         private_chef['backup']['tmp_dir']
        FileUtils.mkdir_p(private_chef['backup']['tmp_dir']).first
      else
        Dir.mktmpdir('pcc_backup')
      end
    end
  end

  def cleanup
    log "Cleaning up #{tmp_dir}"
    FileUtils.rm_r(tmp_dir)
  rescue Errno::ENOENT
    true
  end
end
