# Copyright:: Copyright (c) 2014 Opscode, Inc.
#
# All Rights Reserved

require 'chef_backup/version'
require 'chef_backup/logger'
require 'chef_backup/data_map'
require 'chef_backup/helpers'
require 'chef_backup/backup'
require 'chef_backup/restore'

# ChefBackup factory returns an ChefBackup object
module ChefBackup
  def self.from_config(config)
    type = config['private_chef']['backup']['strategy']
    klass = type.to_s.split('_').map! { |w| w.capitalize }.join
    const_get(klass).new(config)
  rescue NoMethodError, NameError
    msg = "Invalid strategy.  Please set the backup['strategy'] in "
    msg << " /etc/opscode/chef-server.rb and run 'chef-server-ctl reconfigure'"
    puts msg
    exit 1
  end
end

# No module inheritence makes DRY a dull boy
# ChefRestore factory returns an ChefRestore object
module ChefRestore
  def self.from_config(config)
    type = config['private_chef']['backup']['strategy']
    klass = type.to_s.split('_').map! { |w| w.capitalize }.join
    const_get(klass).new(config)
  rescue NoMethodError, NameError
    msg = "Invalid strategy.  Please set the backup['strategy'] in "
    msg << " /etc/opscode/chef-server.rb and run 'chef-server-ctl reconfigure'"
    puts msg
    exit 1
  end
end
