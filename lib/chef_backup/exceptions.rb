module ChefBackup
  module Exceptions
    # ChefBackup Exceptions
    class ChefBackupException < StandardError; end
    class InvalidTarball < ChefBackupException; end
    class InvalidSnapshot < ChefBackupException; end
    class InvalidDatabaseDump < ChefBackupException; end
    class InvalidManifest < ChefBackupException; end
    class InvalidStrategy < ChefBackupException; end
    class NotImplementedError < ChefBackupException; end
  end
end
