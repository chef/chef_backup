require 'highline'

module ChefBackup
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
      @stdout = logfile || $stdout
      @highline = HighLine.new($stdin, @stdout)
    end

    def log(msg, level = :info)
      case level
      when :warn
        msg = "WARNING: #{msg}"
        @stdout.puts( color? ? @highline.color(msg, :yellow) : msg)
      when :error
        msg = "ERROR: #{msg}"
        @stdout.puts( color? ? @highline.color(msg, :red) : msg)
      else
        @stdout.puts(msg)
      end
    end

    def color?
      @stdout.tty?
    end
  end
end
