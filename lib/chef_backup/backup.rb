require 'fileutils'
require 'pathname'

module ChefBackup
  class Backup
    include ChefBackup::Helpers
    include ChefBackup::Exceptions

    attr_reader :restore_param

    #
    # @param running_config [Hash] A hash of the private-chef-running.json
    # @param restore_param [String] A path to tarball or Block Device ID
    #
    # @return [ChefBackup::Backup]
    #
    def initialize(running_config, restore_param = nil)
      ChefBackup::Config.config = running_config
      ChefBackup::Logger.logger(private_chef['backup']['logfile'] || nil)
      @restore_param = restore_param
    end

    #
    # @return [TrueClass, FalseClass] Execute Chef Server backup
    #
    def backup
      @backup ||= ChefBackup::Strategy.backup(backup_strategy)
      @backup.backup
    end

    #
    # @return [TrueClass, FalseClass] Execute Chef Server restore
    #
    def restore
      @backup ||= ChefBackup::Strategy.restore(restore_strategy)
      @restore.restore(restore_param)
    end

    #
    # @return [String] String name of the configured backup strategy
    #
    def backup_strategy
      private_chef['backup']['strategy']
    end

    #
    # @param path [String] A path to backup tarball or EBS snapshot ID
    #
    def restore_strategy
      if tarball?
        unpack_tarball
        manifest['strategy']
      elsif ebs_snapshot?
        'ebs'
      else
        fail InvalidStrategy, "#{restore_param} is not a valid backup"
      end
    end

    #
    # @return [TrueClass, FalseClass] Is the restore_param is a tarball?
    #
    def tarball?
      file = Pathname.new(restore_param)
      file.exist? && file.extname == '.tgz'
    end

    #
    # @return [TrueClass, FalseClass] Is the restore_param an EBS Snapshot?
    #
    def ebs_snapshot?
      # TODO: verify that it's a snapshot
    end

    #
    # @return [TrueClass, FalseClass] Expands tarball into restore directory
    #
    def unpack_tarball
      ensure_file!(restore_param, InvalidTarball, "#{restore_param} not found")
      log "Expanding tarball: #{restore_param}"
      shell_out!("tar zxf #{restore_param} -C #{restore_directory}")
    end

    def ensure_file!(file, exception, message)
      File.exists?(file) ? true : fail(exception, message)
    end

    def backup_name
      @backup_name ||= Pathname.new(restore_param).basename.sub_ext('').to_s
    end

    def restore_directory
      ChefBackup::Config['restore_dir'] ||= begin
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
  end
end
