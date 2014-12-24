# - custom
#   - Verify that backup executable exists and is runnable
#   - exec script
class ChefBackup::Strategy::CustomBackup < ChefBackup::Strategy::TarBackup
  def backup
  end
end
