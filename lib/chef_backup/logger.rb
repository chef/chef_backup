require 'highline'

module ChefBackup
# rubocop:disable IndentationWidth
class Logger
  # rubocop:enable IndentationWidth
  def self.logger(logfile = nil)
    @logger = nil if @logger && logfile && @logger.stdout != logfile
    @logger ||= ChefBackup::Logger.new(logfile)
  end

  def self.log(msg, level = :info)
    logger.log(msg, level)
  end

  attr_accessor :stdout

  def initialize(logfile = nil)
    @stdout = logfile ? logfile : $stdout
    @highline = HighLine.new($stdin, @stdout)
  end

  def log(msg, level = :info)
    case level
    when :warn
      if color?
        @stdout.puts(@highline.color("WARNING: #{msg}", :bright_yellow, :bold))
      else
        @stdout.puts("WARNING: #{msg}")
      end
    when :error
      if color?
        @stdout.puts(@highline.color("ERROR: #{msg}", :red, :bold))
      else
        @stdout.puts("ERROR: #{msg}")
      end
    else
      @stdout.puts msg
    end
  end

  def color?
    @stdout.tty?
  end
end
end
