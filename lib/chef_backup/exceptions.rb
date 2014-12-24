module ChefBackup
  module Exceptions
    class InvalidTarball < StandardError; end
    class InvalidDatabaseDump < StandardError; end
    class InvalidManifest < StandardError; end
    class InvalidStrategy < StandardError; end
    class NotImplementedError < StandardError; end
  end
end
