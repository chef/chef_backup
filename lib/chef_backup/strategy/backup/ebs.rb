# ChefBackup::Ebs class.  To be used when/if Enterprise Chef ever supports EBS
# natively
class ChefBackup::Strategy::EbsBackup < ChefBackup::Strategy::TarBackup
  # - ebs
  #   - Verify AWS credentials exist
  #   - Create backup manifest
  #   - Create backup dir on ebs volume
  #   - Copy /etc/opscode and manifest onto ebs volume
  #   - Take EBS snapshot
  def backup
    ensure_tmp_dir
    verify_ebs
    dump_db if pg_dump?
    create_manifest
    copy_opscode_config
    take_ebs_snapshot
    cleanup
  end

  def verify_ebs; end

  def take_ebs_snapshot; end

  def copy_opscode_config; end
end
