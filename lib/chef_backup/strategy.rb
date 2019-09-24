# Copyright:: Copyright (c) 2014 Chef, Inc.
#
# All Rights Reserved

require "chef_backup/strategy/backup/tar"
require "chef_backup/strategy/backup/lvm"
require "chef_backup/strategy/backup/ebs"
require "chef_backup/strategy/backup/object"
require "chef_backup/strategy/backup/custom"
require "chef_backup/strategy/restore/tar"
require "chef_backup/strategy/restore/lvm"
require "chef_backup/strategy/restore/ebs"
require "chef_backup/strategy/restore/object"
require "chef_backup/strategy/restore/custom"

module ChefBackup
  # ChefBackup::Strategy factory returns an ChefBackup::Strategy object
  module Strategy
    class << self
      def backup(strategy)
        const_get("#{strategy.capitalize}Backup").new
      end

      def restore(strategy, param)
        const_get("#{strategy.capitalize}Restore").new(param)
      end
    end
  end
end
