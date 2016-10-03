require 'simplecov'
SimpleCov.start

require 'chef_backup'
require 'bundler/setup'
require 'json'
require 'tempfile'
require 'chef_backup/deep_merge'

# Merge attributes into existing running_config
def private_chef(*args)
  ChefBackup::Mixin::DeepMerge.deep_merge!(*args, ChefBackup::Config['private_chef'])
end

# Overwrite config with given attributes
def private_chef!(args = {})
  ChefBackup::Config.config = args
end

# Overwrite config with given CLI args
def cli_args!(args)
  ChefBackup::Config.config = args
end

def use_default_running_config
  ChefBackup::Config.config = running_config
end

def use_default_cli_args
  ChefBackup::Config.config = cli_args
end

def clear_config
  ChefBackup::Config.config = {}
end

def set_common_variables
  let(:backup_tarball) { '/tmp/chef-backup-2014-12-10-20-31-40.tgz' }
  let(:backup_time) { '2014-08-21T23:10:57-07:00' }
  let(:tmp_dir) { '/tmp/chef-backup' }
  let(:strategy) { 'test' }
  let(:export_dir) { '/mnt/chef-backups' }
  let(:all_services) do
    %w(nginx oc_bifrost oc_id opscode-erchef opscode-expander
       opscode-expander-reindexer opscode-solr4 postgresql rabbitmq redis_lb
    )
  end
  let(:enabled_services) { all_services }
  let(:data_map) do
    double(
      'DataMap',
      services: {
        'postgresql' => {
          'data_dir' => '/var/opt/opscode/postgresql_9.2/data'
        },
        'couchdb' => {
          'data_dir' => '/var/opt/opscode/couchdb/data'
        },
        'rabbitmq' => {
          'data_dir' => '/var/opt/opscode/rabbitdb/data'
        }
      },
      configs: {
        'opscode' => {
          'data_dir' => '/etc/opscode'
        },
        'opscode-manage' => {
          'data_dir' => '/etc/opscode-manage'
        }
      },
      versions: {
        'opscode' => {'version'=>"12.9.1", 'revision'=>"aa7b99ac81ff4c018a0081e9a273b87b15342f12", 'path'=>"/opt/opscode/version-manifest.json"},
        'opscode-manage' => {'version'=>"1.2.3", 'revision'=>"deadbeef", 'path'=>"/opt/opscode-manage/version-manifest.json"}
      }
    )
  end
end

def running_config
  @config ||= begin
    f = File.expand_path('../fixtures/chef-server-running.json', __FILE__)
    JSON.parse(File.read(f))
  end
  @config.dup
end

def cli_args
  {
    'tmp_dir' => '/tmp/chef_backup/tmp_dir',
    'agree_to_cleanse' => nil,
    'restore_arg' => '/tmp/chef_backup/backup.tgz',
    'restore_dir' => File.join('/tmp/chef_backup/tmp_dir', 'restore_dir')
  }
end

RSpec.configure do |rspec|
  rspec.run_all_when_everything_filtered = true
  rspec.filter_run :focus
  rspec.order = 'random'
  rspec.expect_with(:rspec) { |c| c.syntax = :expect }
  rspec.before { allow($stdout).to receive(:write) }
end
