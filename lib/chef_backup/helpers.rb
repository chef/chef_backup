require 'fileutils'
require 'json'
require 'mixlib/shellout'
require 'chef_backup/config'
require 'chef_backup/logger'

# rubocop:disable ModuleLength
# rubocop:disable IndentationWidth
module ChefBackup
# Common helper methods that are usefull in many classes
module Helpers
  # rubocop:enable IndentationWidth

  SERVER_ADD_ONS = {
    'opscode-manage' => {
      'config_file' => '/etc/opscode-manage/manage.rb',
      'ctl_command' => 'opscode-manage-ctl'
    },
    'opscode-reporting' => {
      'config_file' => '/etc/opscode-reporting/opscode-reporting.rb',
      'ctl_command' => 'opscode-reporting-ctl'
    },
    'opscode-push-jobs-server' => {
      'config_file' => '/etc/opscode-push-jobs-server/opscode-push-jobs-server.rb',
      'ctl_command' => 'opscode-push-jobs-server-ctl'
    },
    'opscode-analytics' => {
      'config_file' => '/etc/opscode-analytics/opscode-analytics.rb',
      'ctl_command' => 'opscode-analytics-ctl'
    },
    'chef-ha' => {
      'config_file' => '/etc/opscode/chef-server.rb'
    },
    'chef-sync' => {
      'config_file' => '/etc/chef-sync/chef-sync.rb',
      'ctl_command' => 'chef-sync-ctl'
    },
    'chef-marketplace' => {
      'config_file' => '/etc/chef-marketplace/marketplace.rb',
      'ctl_command' => 'chef-marketplace-ctl'
    }
  }.freeze

  DEFAULT_PG_OPTIONS = '-c statement_timeout=3600000'.freeze

  def config
    ChefBackup::Config
  end

  def config_base
    ChefBackup::Config['config_base']
  end

  def service_config
    ChefBackup::Config[config_base]
  end

  def ctl_command
    service_config['backup']['ctl-command']
  end

  def running_filepath
    service_config['backup']['running_filepath']
  end

  def database_name
    service_config['backup']['database_name']
  end

  def log(message, level = :info)
    ChefBackup::Logger.logger.log(message, level)
  end

  # Note that when we are in the backup codepath, we have access to a running
  # chef server and hence, the ctl command puts all our flags under the current
  # running service namespace. The lets the default configuration of the server
  # provide flags that the user doesn't necessarily provide on the command line.
  #
  # During the restore codepath, there may be no running chef server. This means
  # that we need to be paranoid about the existence of the service_config hash.
  def shell_timeout
    option = config['shell_out_timeout'] ||
             (service_config && service_config['backup']['shell_out_timeout'])
    option.to_f unless option.nil?
  end

  #
  # @param file [String] A path to a file on disk
  # @param exception [Exception] An exception to raise if file is not present
  # @param message [String] Exception message to raise
  #
  # @return [TrueClass, FalseClass]
  #
  def ensure_file!(file, exception, message)
    File.exist?(file) ? true : raise(exception, message)
  end

  def shell_out(*command)
    options = command.last.is_a?(Hash) ? command.pop : {}
    opts_with_defaults = { 'timeout' => shell_timeout }.merge(options)
    cmd = Mixlib::ShellOut.new(*command, opts_with_defaults)
    cmd.live_stream ||= $stdout.tty? ? $stdout : nil
    cmd.run_command
    cmd
  end

  def shell_out!(*command)
    cmd = shell_out(*command)
    cmd.error!
    cmd
  end

  def project_name
    service_config['backup']['project_name']
  end

  def base_install_dir
    "/opt/#{project_name}"
  end

  def addon_install_dir(name)
    # can use extra field in SERVER_ADD_ONS to extend if someone isn't following this pattern.
    "/opt/#{name}"
  end

  def base_config_dir
    "/etc/#{project_name}"
  end

  def chpst
    "#{base_install_dir}/embedded/bin/chpst"
  end

  def pgsql
    "#{base_install_dir}/embedded/bin/psql"
  end

  def pg_options
    config['pg_options'] ||
      (service_config && service_config['backup']['pg_options']) ||
      DEFAULT_PG_OPTIONS
  end

  def all_services
    Dir["#{base_install_dir}/sv/*"].map { |f| File.basename(f) }.sort
  end

  def enabled_services
    all_services.select { |sv| service_enabled?(sv) }
  end

  def disabled_services
    all_services.select { |sv| !service_enabled?(sv) }
  end

  def service_enabled?(service)
    File.symlink?("#{base_install_dir}/service/#{service}")
  end

  def stop_service(service)
    res = shell_out("#{ctl_command} stop #{service}")
    res
  end

  def start_service(service)
    res = shell_out("#{ctl_command} start #{service}")
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

  def restart_chef_server
    shell_out("#{ctl_command} restart #{service}")
  end

  def reconfigure_add_ons
    enabled_addons.each do |_name, config|
      shell_out("#{config['ctl_command']} reconfigure") if config.key?('ctl_command')
    end
  end

  def restart_add_ons
    enabled_addons.each do |_name, config|
      shell_out("#{config['ctl_command']} restart") if config.key?('ctl_command')
    end
  end

  def reconfigure_marketplace
    log 'Setting up Chef Marketplace'
    shell_out('chef-marketplace-ctl reconfigure')
  end

  def enabled_addons
    SERVER_ADD_ONS.select do |name, config|
      !config['config_file'].nil? &&
        File.directory?(File.dirname(config['config_file'])) &&
        File.directory?(addon_install_dir(name))
    end
  end

  def strategy
    service_config['backup']['strategy']
  end

  def topology
    service_config['topology']
  end

  def frontend?
    service_config['role'] == 'frontend'
  end

  def backend?
    service_config['role'] =~ /backend|standalone/
  end

  def online?
    service_config['backup']['mode'] == 'online'
  end

  def ha?
    topology == 'ha'
  end

  def tier?
    topology == 'tier'
  end

  def standalone?
    topology == 'standalone'
  end

  def marketplace?
    shell_out('which chef-marketplace-ctl').exitstatus == 0
  end

  def tmp_dir
    @tmp_dir ||= begin
      dir = safe_key { config['tmp_dir'] } ||
            safe_key { service_config['backup']['tmp_dir'] }
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

  def version_from_manifest_file(file)
    return :no_version if file.nil?

    path = File.expand_path(file)
    if File.exist?(path)
      config = JSON.parse(File.read(path))
      { 'version' => config['build_version'],
        'revision' => config['build_git_revision'],
        'path' => path }
    else
      :no_version
    end
  end

  private

  def safe_key
    yield
  rescue NameError
    nil
  end
end
end
