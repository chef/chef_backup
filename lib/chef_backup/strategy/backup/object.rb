# ChefBackup::Object class.  Used to backup all stateful services as an object
# and stored locally in a filesystem structure in JSON.
class ChefBackup::Strategy::ObjectBackup < ChefBackup::Strategy::TarBackup
  # - object
  #   - Make tmp directory
  #   - Ensure backup directory exists
  #   - Warn if backups directory or tmp are low on space
  #   - knife-ec-backup into temp directory
  #   - Create backup manifest
  #   - Create gzipped tarball of all required files
  #     - knife ec backup dump
  #     - /etc/opscode
  #     - Backup manifest
  #   - Cleanup tmp directories
  def backup
    ensure_tmp_dir
    verify_object
    knife_ec_backup
    create_manifest
    create_tarball
    cleanup
  end

  def verify_object
  end

  def knife_ec_backup
  end
end
