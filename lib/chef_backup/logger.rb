module ChefBackup
  # Basic Logging Class
  class Logger
    def self.logger(logfile = nil)
      @logger = nil if @logger && logfile && @logger.stdout != logfile
      @logger ||= new(logfile)
    end

    def self.log(msg, level = :info)
      logger.log(msg, level)
    end

    attr_accessor :stdout

    def initialize(logfile = nil)
      $stdout = logfile ? File.open(logfile, "ab") : $stdout
    end

    # pastel.decorate is a lightweight replacement for highline.color
    def pastel
      @pastel ||= begin
        require "pastel" unless defined?(Pastel)
        Pastel.new
      end
    end

    def log(msg, level = :info)
      case level
      when :warn
        msg = "WARNING: #{msg}"
        $stdout.puts(color? ? pastel.decorate(msg, :yellow) : msg)
      when :error
        msg = "ERROR: #{msg}"
        $stdout.puts(color? ? pastel.decorate(msg, :red) : msg)
      else
        $stdout.puts(msg)
      end
    end

    def color?
      $stdout.tty?
    end
  end
end
