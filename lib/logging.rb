###############
# Logging Class
###############

require 'logger'

module Log
  def self.make_logger level: :info, fmt: :standard, color: true
    @logger = Logger.new(STDOUT, progname: 'backupchain')
    @logger.level = level
    original_formatter = @logger.formatter || Logger::Formatter.new
    # I, [2024-04-17T20:51:35.082933 #70631]  INFO -- backupchain: "foo"

    colors = {
      'DEBUG' => :blue,
      'INFO' => :green,
      'WARN' => :yellow,
      'ERROR' => :red,
      'FATAL' => { background: :red },
      'ANY' => :default
    }

    @logger.formatter = proc do |severity, time, progname, msg|
      # original_formatter.call(severity, time, progname, msg.dump)
      msg.lines.map { |m|
        if fmt == :standard
          "[#{time.strftime("%Y-%m-%d %H:%M:%S.%6N")}] #{progname} || #{severity + (' ' * (5 - severity.length))} || #{m.strip_color}" # Strips color from the message
        elsif fmt == :simple
          "#{severity.colorize(colors[severity]) + (' ' * (5 - severity.length))} || #{m}"
        elsif fmt == :display
          severity == 'INFO' ? m : "#{severity.colorize(colors[severity]) + (' ' * (5 - severity.length))} || #{m}"
        end
      }.join + "\n"
    end
  end

  def self.log
    @logger || self.make_logger
  end
end

module System
  def self.log
    Log::log
  end

  def self.debug obj
    puts obj.to_s.colorize(:red)
  end
end
