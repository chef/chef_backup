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
    @private_chef = default_config.merge(running_config['private_chef'])
    @base_path = '/opt/opscode'
    @sv_path = "#{base_path}/sv"
    @backup_time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
    init_logging
  end

  def backup
    not_implemented
  end

  def init_logging
    log = begin
            if private_chef['backup'].key?('logfile')
              private_chef['backup']['logfile']
            else
              nil
            end
          end
    @log = ChefBackup::Logger.logger(log)
  end

  def log(msg, level = :warn)
    @log.log(msg, level)
  end

  def tmp_dir
    @tmp_dir ||=
      if private_chef['backup'].key?('tmp_dir') &&
         private_chef['backup']['tmp_dir']
        FileUtils.mkdir_p(private_chef['backup']['tmp_dir']).first
      else
        Dir.mktmpdir('pcc_backup')
      end
  end

  def export_dir
    @export_dir ||= begin
      dir =
        if private_chef['backup']['export_dir']
          private_chef['backup']['export_dir']
        else
          log(["WARNING: backup['export_dir'] has not been set.",
               'defaulting to: /var/opt/chef-backups'].join(' ')
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

  def cleanup
    log "Cleaning up #{tmp_dir}"
    FileUtils.rm_r(tmp_dir)
  rescue Errno::ENOENT
    true
  end

  private

  def default_config
    { 'backup' =>
      { 'always_dump_db' => true,
        'strategy' => 'none',
        'export_dir' => '/var/opt/chef-backup'
      }
    }
  end

  def enabled_addons
    @enabled_addons ||= %w(
      opscode-manage
      opscode-reporting
      opscode-push-jobs-server
      opscode-analytics
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

  def online?
    not_implemented
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

  def not_implemented
    msg = "#{caller[0].split[1]} is not implemented for this strategy"
    fail NotImplementedError, msg
  end
end
end
