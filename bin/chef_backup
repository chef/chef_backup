#!/opt/chef/embedded/bin/ruby

# An executable binary for older servers that don't have
# `chef-server-ctl backup`  Only supports the 'tar' strategy
#
# To use:
#   rake install
#   bin/backup.rb

require 'chef_backup'
require 'json'

f = '/etc/opscode/chef-server-running.json'
running_config = JSON.parse(File.read(f))
running_config['private_chef']['backup'] = { 'strategy' => 'tar' }
@runner = ChefBackup::Runner.new(
  running_config
)
status = @runner.backup
exit(status ? 0 : 1)
