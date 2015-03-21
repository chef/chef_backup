require 'fileutils'
require 'mixlib/shellout'
require 'chef_backup/config'
require 'chef_backup/logger'

# rubocop:disable IndentationWidth
module ChefBackup
# Common helper methods that are usefull in many classes
module Helpers
  # rubocop:enable IndentationWidth

  SERVER_ADD_ONS = %w(
    opscode-manage
    opscode-reporting
    opscode-push-jobs-server
    opscode-analytics
    chef-ha
    chef-sync
  ).freeze

  def private_chef
    config['private_chef']
  end

  def config
    ChefBackup::Config
  end

  def log(message, level = :info)
    ChefBackup::Logger.logger.log(message, level)
  end

  #
  # @param file [String] A path to a file on disk
  # @param exception [Exception] An exception to raise if file is not present
  # @param message [String] Exception message to raise
  #
  # @return [TrueClass, FalseClass]
  #
  def ensure_file!(file, exception, message)
    File.exist?(file) ? true : fail(exception, message)
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
    SERVER_ADD_ONS.select { |service| addon?(service) }
  end

  def addon?(service)
    File.directory?("/etc/#{service}")
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
    @tmp_dir ||= begin
      dir = safe_key { config['tmp_dir'] } ||
            safe_key { private_chef['backup']['tmp_dir'] }
      if dir
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
        dir
      else
        Dir.mktmpdir('chef_backup')
      end
    end
  end

  def cleanup
    log "Cleaning up #{tmp_dir}"
    FileUtils.rm_r(tmp_dir)
  rescue Errno::ENOENT
    true
  end

  private

  def safe_key
    yield
  rescue NameError
    nil
  end
end
end
