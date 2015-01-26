require 'fileutils'
require 'pathname'

module ChefBackup
  # ChefBackup::Runner class initializes the strategy and runs the action
  class Runner
    include ChefBackup::Helpers
    include ChefBackup::Exceptions

    attr_reader :restore_param

    #
    # @param running_config [Hash] A hash of the private-chef-running.json
    # @param restore_param [String] A path to tarball or Block Device ID
    #
    # @return [ChefBackup::Runner]
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
      @restore ||= ChefBackup::Strategy.restore(restore_strategy, restore_param)
      @restore.restore
    end

    #
    # @return [String] String name of the configured backup strategy
    #
    def backup_strategy
      private_chef['backup']['strategy']
    end

    #
    # @return [String] A path to backup tarball or EBS snapshot ID
    #
    def restore_strategy
      @restore_strategy ||= begin
        if tarball?
          unpack_tarball
          manifest['strategy']
        elsif ebs_snapshot?
          'ebs'
        else
          fail InvalidStrategy, "#{restore_param} is not a valid backup"
        end
      end
    end

    #
    # @return [TrueClass, FalseClass] Is the restore_param is a tarball?
    #
    def tarball?
      file = Pathname.new(File.expand_path(restore_param))
      file.exist? && file.extname == '.tgz'
    end

    #
    # @return [TrueClass, FalseClass] Is the restore_param an EBS Snapshot ID?
    #
    def ebs_snapshot?
      restore_param =~ /^snap-\h{8}$/
    end

    #
    # @return [TrueClass, FalseClass] Expands tarball into restore directory
    #
    def unpack_tarball
      file = File.expand_path(restore_param)
      ensure_file!(file, InvalidTarball, "#{file} not found")
      log "Expanding tarball: #{file}"
      shell_out!("tar zxf #{file} -C #{restore_directory}")
    end

    #
    # @return [String] The backup name from the restore param
    #
    def backup_name
      if tarball?
        Pathname.new(restore_param).basename.sub_ext('').to_s
      elsif ebs_snapshot?
        restore_param
      end
    end

    #
    # Sets the restore_dir in ChefBackup::Config and ensures the directory
    # exists and is cleaned.
    #
    # @return [String] A path to the restore directory
    #
    def restore_directory
      ChefBackup::Config['restore_dir'] ||= begin
        dir_name = File.join(tmp_dir, backup_name)
        if File.directory?(dir_name)
          # clean restore directory if it exists
          FileUtils.rm_r(Dir.glob("#{dir_name}/*"))
        else
          FileUtils.mkdir_p(dir_name)
        end
        dir_name
      end
    end

    #
    # @return [Hash] A parsed copy of the manifest.json in the backup tarball
    #
    def manifest
      @manifest ||= begin
        file = "#{restore_directory}/manifest.json"
        ensure_file!(file, InvalidTarball, 'No manifest found in tarball')
        JSON.parse(File.read(file))
      end
    end
  end
end
