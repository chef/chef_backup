# ChefBackup::Lvm class.  Class used when Enterprise Chef's stateful services
# are on an LVM logical volume.  This may allow us to not require a pg_dump,
# instead relying on pg_crash recovery.  Not doing a pg_dump will greatly
# speed up backups.
class ChefBackup::Strategy::LvmBackup < ChefBackup::Strategy::TarBackup
  #   - verify config
  #   - Verify lv and vg existence
  #   - Warn if space is low in vg for an lvm snapshot
  #   - Ensure backup directory exists
  #   - Create temp backup dir
  #   - Do DB dump (if we have to)
  #   - Create backup manifest
  #   - Take LVM snapshot
  #   - Mount LVM snapshot
  #   - Create a gzipped tarball of all required files
  #     - db dump (if we have to)
  #     - /etc/opscode
  #     - Backup manifest
  #     - mounted LVM snapshot
  #   - Cleanup tmp directories
  def backup
    ensure_tmp_dir
    verify_lvm
    dump_db if pg_dump?
    create_manifest
    take_lvm_snapshot
    mount_lvm_snapshot
    create_tarball
    cleanup
  end

  def verify_lvm
    # verify lv and vg are available
    # warn if vg space is low
  end

  def take_lvm_snapshot
  end

  def mount_lvm_snapshot
  end
end
