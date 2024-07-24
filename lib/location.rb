###############
# Location Classes
###############
class Location
  def self.create name: nil, root: nil, ssh: nil, disk: false, highlight_color: nil, max_threads: nil
    params = binding.local_variables.select { |var| var != :params }.map { |var| [var.to_sym, binding.local_variable_get(var)] }.to_h
    if ssh.nil? && !disk
      return LocalFolder.new *params
    elsif ssh.nil? && disk
      return LocalRemovableDisk.new *params
    elsif !ssh.nil? && !disk
      return RemoteFolder.new *params
    elsif !ssh.nil? && disk
      return RemoteRemovableDisk.new *params
    end
  end

  def initialize name: nil, root: nil, ssh: nil, disk: false, highlight_color: nil, max_threads: nil
    binding.local_variables.each do |var|
      self.instance_variable_set("@#{var}", binding.local_variable_get(var.to_sym))
      self.class.instance_eval { attr_reader var.to_sym }
    end
    @root = File.expand_path(@root)
    @highlight_color = @highlight_color.nil? ? :default : @highlight_color.to_sym
    @mutex = Mutex.new
    @max_threads ||= {}
    @max_threads [:read] ||= 1
    @max_threads [:write] ||= 1
    @readers = 0
    @writers = 0
  end

  attr_reader :max_threads

  def add_reader
    ready = false
    loop do
      @mutex.lock
      if @readers < @max_threads[:read] && @writers == 0
        @readers += 1
        ready = true
      end
      @mutex.unlock
      break if ready
      sleep 1
    end
  end

  def add_writer
    ready = false
    loop do
      @mutex.lock
      if @writers < @max_threads[:write] && @readers == 0
        @writers += 1
        ready = true
      end
      @mutex.unlock
      break if ready
      sleep 1
    end
  end

  def del_reader
    @mutex.lock
    @readers -= 1 unless @readers == 0
    @mutex.unlock
  end

  def del_writer
    @mutex.lock
    @writers -= 1 unless @writers == 0
    @mutex.unlock
  end

  def lock
    @mutex.lock
  end

  def unlock
    @mutex.unlock
  end

  def analyze! allow_automount: false
    System.log.info "Analyzing #{@name}..."
    self.available? force_check: true
    System.log.info self.status_message
    if allow_automount && self.can_automount?
      System.log.info "Attempting to automount disk on #{@name}..."
      success = self.automount!
      System.log.info "Automounting disk on #{@name} " + (success ? 'succeeded'.colorize(:green) : 'failed'.colorize(:red))
      if success
        System.log.info "Re-analyzing #{@name}..."
        self.available? force_check: true
        System.log.info self.status_message
      end
    end
  end

  def available? force_check: false
    return @_available if defined?(@_available) && !@_available.nil? && !force_check
    @_available = host_available? && root_available?
  end

  def status_message
    [host_status_message, root_status_message].join("\n")
  end

  def operating_system
    return @_operating_system if defined?(@_operating_system)
    uname = run_command!('uname', capture_output: true, silent: true).downcase.chomp
    case uname
    when 'linux'
      @_operating_system = :linux
    when 'darwin'
      @_operating_system = :darwin
    else
      raise Exception.new("Unsupported Operating System Detected on #{@name}: #{uname}.")
    end
    System.log.debug "Detected #{uname.capitalize} OS running on #{@name}"
    @_operating_system
  end

  def rsync_executable_path
    return @_executable_path if defined?(@_executable_path)
    path = run_command!("find /opt/homebrew/Cellar/rsync -name 'rsync' | grep 'bin'", capture_output: true, silent: true).chomp
    path = 'rsync' unless path.include?('rsync')
    System.log.debug("Found rsync executable for #{@name.colorize(@highlight_color)} at #{path}")
    @_executable_path = path
  end

  def run_command! cmd, capture_output: false, silent: false, prefix: nil, color: nil, bgcolor: nil
    output = ''
    retval = nil
    prefix ||= ''
    System.log.debug "Running command: #{cmd.chomp}"
    Open3.popen2e(cmd) do |stdin, stdouterr, wait_thr|
      until (line = stdouterr.gets).nil? do
        output << line
        System.log.info(prefix + line.chomp.colorize(color: color, background: bgcolor)) unless silent
        System.log.add(-1, prefix + line.chomp.colorize(color: color, background: bgcolor)) if silent
      end
      retval = wait_thr.value
    end
    capture_output ? output : retval.success?
  end
end

require_relative 'location_types/folder.rb'
require_relative 'location_types/removabledisk.rb'
require_relative 'locations/local.rb'
require_relative 'locations/remote.rb'
