#!/usr/bin/env ruby

##################################################
############### Full Backup Script ###############
##################################################
## (C)opyright 2024 Andrew Khoury
##   Email: akhoury@live.com
######
## README:
##   This is an easily configurable script that
## uses RSync to back up data to multiple targets.
######
## License: GPLv3 w/ Commons Clause
## For the full license text, see the file LICENSE.md at:
##   https://github.com/akhoury6/backupchain/blob/master/LICENSE.txt
###################################################
###############
# Metadata
###############
AUTHOR="Andrew Khoury"
EMAIL="akhoury@live.com"
PRGNAME="backupchain"
COPYRIGHT="2024"
VERSION="0.5.0"
LICENSE="GPLv3 with Commons Clause"

###############
# Safety First
###############
if `ps aux | grep -v 'grep' | grep '#{File.basename(__FILE__)}' | wc -l`.strip.to_i > 1
  puts "A backup is already running. Please wait for it to finish or exit it before running another backup."
  exit 1
end

###############
# Imports & Class Overrides
###############
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  ruby '>= 3.3'
  gem 'colorize', '~> 1.1', require: true
  gem 'json-schema', '~> 4.3', require: true
  gem 'base64', '~> 0.2', require: true
  # bigdecimal is added here temporarily until json-schema adds it to their gemspec
  gem 'bigdecimal', '~> 3.1', require: false
end

%w(yaml open3 io/console zlib).each{ |lib| require lib }

class File
  def self.full_expand_path path
    f = self.expand_path(path)
    self.symlink?(f) ? self.readlink(f) : f
  end
end
String.instance_eval{define_method(:compress){Base64.encode64(Zlib::Deflate.deflate(self))}}
String.instance_eval{define_method(:decompress){Zlib::Inflate.inflate(Base64.decode64(self))}}
String.instance_eval{define_method(:strip_color){self.gsub(/\e\[([;\d]+)?m/, '')}}

# Project Imports
MAINDIR = File.symlink?(__FILE__) ? File.expand_path(File.dirname(File.readlink(__FILE__))) : File.expand_path(File.dirname(__FILE__))
LIBDIR = File.join(MAINDIR, 'lib')
###############
# Location Classes
###############
class Location
  def self.create name: nil, root: nil, ssh: nil, disk: false, highlight_color: nil, max_threads: nil
    params = binding.local_variables.select{ |var| var != :params }.map{ |var| [var.to_sym, binding.local_variable_get(var)] }.to_h
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
      self.class.instance_eval{ attr_reader var.to_sym }
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

module FolderModule
  private def root_available?
    @_root_available = run_command!("test -d '#{@root}' && test -r '#{@root}' && test -w '#{@root}'")
  end

  private def root_status_message
    return @root.colorize(@highlight_color) + ' is in an ' + 'unknown'.colorize(:gray) + ' state.' if !defined?(@_root_available)
    return @root.colorize(@highlight_color) + ' is ' + 'present'.colorize(@highlight_color) if @_root_available
    return @root.colorize(@highlight_color) + ' is ' + 'missing'.colorize(:red)
  end

  def can_automount?
    false
  end

  def can_fsck?
    false
  end
end
module RemovableDiskModule
  private def root_available?
    diskinfo = run_command!("test -d '#{@root}' && test -r '#{@root}' && test -w '#{@root}' && df '#{@root}' | grep ' #{@root}'", capture_output: true, silent: true)
    @_root_available = !diskinfo.empty?
    if @_root_available && @disk.keys.include?(:uuid)
      if operating_system == :linux
        device_path_df = diskinfo.chomp.split(' ').first
        device_path_blkid = run_command!("sudo blkid --match-token UUID=#{@disk[:uuid].downcase}", capture_output: true, silent: true).split(':').first
        @_root_available = (device_path_df == device_path_blkid)
      elsif operating_system == :darwin
        device_path_df = diskinfo.chomp.split(' ').first
        device_info = run_command!("diskutil info #{device_path_df}", capture_output: true, silent: true).lines.map{|l| l.chomp}.reject(&:empty?).map{|l| l.split(':').map{|h| h.strip}}.reject{|arr| arr.length != 2}.to_h
        @_root_available = device_info.keys.include?('Volume UUID') && device_info['Volume UUID'] == @disk[:uuid].upcase
      end
    end
    @_root_available
  end

  private def root_status_message
    return @root.colorize(@highlight_color) + ' is in an ' + 'unknown'.colorize(:gray) + ' state.' if !defined?(@_root_available)
    return @root.colorize(@highlight_color) + ' is ' + 'present'.colorize(@highlight_color) if @_root_available
    return @root.colorize(@highlight_color) + ' is ' + 'missing'.colorize(:red)
  end

  def can_automount?
    !@_root_available && defined?(@_host_available) && @_host_available && @disk.is_a?(Hash) && @disk[:automount]
  end

  def automount!
    return true if @_root_available
    return false unless can_automount?

    if operating_system == :linux
      # First ensure the device is connected and get its details
      blkid_info = run_command!("sudo blkid --match-token UUID=#{@disk[:uuid].downcase}", capture_output: true, silent: true)
      return false if blkid_info.empty?
      blkid_info = ("DEVICE=" + blkid_info.sub(':','')).gsub('"', '').split(' ').map{|e| e.split('=')}.to_h
      # Mount the disk
      run_command!('sudo mount "' + blkid_info['DEVICE'] + '" --target "' + @root + '"')
    elsif operating_system == :darwin
      # First ensure the device is connected and get its details
      all_disk_info = run_command!("diskutil info -all", capture_output: true, silent: true)
      all_disk_info = all_disk_info.split('**********').map{|drive| drive.lines.map{|l| l.strip}.reject(&:empty?).map{|l| l.split(':').map{|h| h.strip}}.reject{|arr| arr.length != 2}.to_h }.reject(&:empty?)
      return false if ! diskinfo = all_disk_info.select{|disk| disk.keys.include?('Volume UUID') && disk['Volume UUID'] == @disk[:uuid].upcase}[0]
      run_command!('diskutil mount "' + diskinfo['Device Node'] + '"')
    end
    @_available = nil
    root_available?
  end

  def can_fsck?
    !defined?(@_fsck_status) && defined?(@_available) && @_available && @disk.is_a?(Hash) && @disk.keys.include?(:can_fsck) && @disk[:can_fsck]
  end

  def run_fsck! highlight: false
    return false if defined?(@_fsck_status)
    return @_fsck_status = 1 unless can_fsck?

    System.log.info "Running fsck on #{@name.colorize(@highlight_color)}"

    if operating_system == :linux
      # Find device path & mountpoint for the given root
      part, *_, mountpoint = run_command!("df '#{@root}' | tail -n1", capture_output: true, silent: true).chomp.split(' ')
      return @_fsck_status = 2 unless /^\/dev\//.match?(part) && mountpoint != '/'
      # Get current mount parameters
      fs = Hash.new
      fs[:spec], fs[:file], fs[:vfstype], fs[:mntops], fs[:freq], fs[:passno] = run_command!("cat /proc/mounts | grep \"#{part} #{mountpoint} \"", capture_output: true, silent: true).chomp.split(' ')
      return @_fsck_status = 2 unless /^\/dev\//.match?(fs[:spec]) && fs[:file] != '/'
      fsck_cmd = "fsck." + fs[:vfstype]
      return @_fsck_status = 3 unless run_command!("which #{fsck_cmd}", capture_output: false, silent: true)
      # Run fsck and remount
      System.log.info "Checking partition #{fs[:spec].colorize(@highlight_color)} mounted at #{fs[:file].colorize(@highlight_color)} on #{@name}...".colorize(highlight && @highlight_color)
      # run_command!("sudo umount '#{fs[:spec]}' && sudo #{fsck_cmd} -fy '#{fs[:spec]}'; sudo mount '#{fs[:spec]}' --target '#{fs[:file]}' --options '#{fs[:mntops]}'")
      return @_fsck_status = 4 unless run_command!("sudo umount '#{fs[:spec]}'", silent: true)
      return @_fsck_status = 5 unless run_command!("sudo #{fsck_cmd} -fy '#{fs[:spec]}'", color: highlight && @highlight_color)
      return @_fsck_status = 6 unless run_command!("sudo mount '#{fs[:spec]}' --target '#{fs[:file]}' --options '#{fs[:mntops]}'", silent: true)

    elsif operating_system == :darwin
      # Find device path & mountpoint for the given root
      part, *_, mountpoint = run_command!("df '#{@root}' | tail -n1", capture_output: true, silent: true).chomp.split(' ')
      return @_fsck_status = 2 unless /^\/dev\//.match?(part) && mountpoint != '/'
      # We get the device info.
      device_info = run_command!("diskutil info #{part}", capture_output: true, silent: true).lines.map{|l| l.chomp}.reject(&:empty?).map{|l| l.split(':').map{|h| h.strip}}.reject{|arr| arr.length != 2}.to_h
      return @_fsck_status = 2 unless /^\/dev\//.match?(device_info['Device Node']) && device_info['Mount Point'] != '/'
      fsck_cmd = "fsck_" + device_info['Type (Bundle)']
      return @_fsck_status = 3 unless run_command!("which #{fsck_cmd}", capture_output: false, silent: true)
      # Run fsck and remount
      System.log.info "Checking partition #{part.colorize(@highlight_color)} mounted at #{mountpoint.colorize(@highlight_color)} on #{@name}...".colorize(highlight && @highlight_color)
      # return @_fsck_status = run_command!("sudo diskutil unmount '#{part}' || exit 4 && sudo #{fsck_cmd} -fy '#{part}' || exit 5; sudo diskutil mount '#{part}' || exit 6")
      return @_fsck_status = 4 unless run_command!("sudo diskutil unmount #{part}", silent: true)
      return @_fsck_status = 5 unless run_command!("sudo #{fsck_cmd} -fy #{part}", color: highlight && @highlight_color)
      return @_fsck_status = 6 unless run_command!("sudo diskutil mount #{part}", silent: true)

    end
    @_fsck_status = 0
  end

  def fsck_status_handler highlight: false
    if !defined?(@_fsck_status)
      System.log.debug "Fsck has not yet been run on #{@name.colorize(@highlight_color)}.".colorize(highlight && @highlight_color)
      return
    end
    case @_fsck_status
    when 0
      System.log.info "Fsck completed ".colorize(highlight && @highlight_color) + 'successfully'.colorize(:green) + " on #{@name.colorize(@highlight_color)}".colorize(highlight && @highlight_color)
    when 1
      System.log.debug "Location #{@name.colorize(@highlight_color)} does not have the fsck check enabled.".colorize(highlight && @highlight_color)
    when 2
      System.log.error "Could not run fsck on #{@name.colorize(@highlight_color)}. Could not find mountpoint for #{@root.colorize(@highlight_color)}.".colorize(highlight && @highlight_color)
    when 3
      System.log.error "Could not run fsck on #{@name.colorize(@highlight_color)}. The filesystem on #{@root.colorize(@highlight_color)} does not have a compatible fsck executable on the host.".colorize(highlight && @highlight_color)
    when 4
      System.log.error "Could not run fsck on #{@name.colorize(@highlight_color)}. Could not unmount the filesystem at #{@root.colorize(@highlight_color)}.".colorize(highlight && @highlight_color)
    when 5
      System.log.fatal "Could not run fsck on #{@name.colorize(@highlight_color)}. The drive is unmounted but fsck check did not run or did not run correctly. Halting execution to prevent unintended consequences.".colorize(highlight && @highlight_color)
      @_root_available = false
      @_available = false
      exit 1
    when 6
      System.log.fatal "Error running fsck on #{@name.colorize(@highlight_color)}. The volume could not be re-mounted at #{@root.colorize(@highlight_color)}. Halting execution to prevent unintended consequences.".colorize(highlight && @highlight_color)
      @_root_available = false
      @_available = false
      exit 1
    end
  end
end
class LocalHost < Location
  def initialize params
    super **params
  end

  def connection_parameters
    {
      host: nil,
      port: nil,
      root: @root,
      user: nil,
      keyfile: nil
    }
  end

  private

  def host_available?
    @_host_available = true
  end

  def host_status_message
    return @name.colorize(@highlight_color) + ' is in an ' + 'unknown'.colorize(:gray) + ' state. Please check for availability before using it.' if !defined?(@_host_available)
    return @name.colorize(@highlight_color) + ' is ' + 'available'.colorize(@highlight_color)
  end
end

class LocalFolder < LocalHost
  include FolderModule
  def initialize *params
    super **params.to_h
  end
end

class LocalRemovableDisk < LocalHost
  include RemovableDiskModule
  def initialize *params
    super **params.to_h
  end
end
class RemoteHost < Location
  def initialize params
    super **params
    @ssh[:credentials][:keyfile] = File.full_expand_path(@ssh[:credentials][:keyfile]) if @ssh.keys.include?(:credentials) && @ssh[:credentials].keys.include?(:keyfile)
    @ssh_port_cache = nil
  end

  attr_reader :loc

  def connection_parameters
    return @_connparams if defined?(@_connparams)
    @_connparams = {
      host: @ssh[@loc][:addr],
      port: @ssh[@loc].keys.include?(:port) ? @ssh[@loc][:port] : nil,
      root: @root,
      user: @ssh.keys.include?(:credentials) && @ssh[:credentials].keys.include?(:user) ? @ssh[:credentials][:user] : nil,
      keyfile: @ssh.keys.include?(:credentials) && @ssh[:credentials].keys.include?(:keyfile) ? @ssh[:credentials][:keyfile] : nil
    }
  end

  def run_command! cmd, capture_output: false, silent: false, color: nil, bgcolor: nil
    raise Exception.new("Remote host #{@name} needs to be analyzed before commands can be executed.") unless @loc
    fullcmd = "ssh"
    fullcmd += " -p #{@ssh[@loc][:port]}" if @ssh[@loc].keys.include?(:port)
    fullcmd += " -i '#{@ssh[:credentials][:keyfile]}'" if @ssh.keys.include?(:credentials) && @ssh[:credentials].keys.include?(:keyfile)
    fullcmd += ' '
    fullcmd += @ssh[:credentials][:user] + '@' if @ssh.keys.include?(:credentials) && @ssh[:credentials].keys.include?(:user)
    fullcmd += @ssh[@loc][:addr] + ' '
    fullcmd += "'#{cmd.gsub("'", "'\"'\"'")}'"
    cmd = fullcmd
    super
  end

  private

  def host_available?
    [:local, :remote].select{ |loc| @ssh.keys.include?(loc) }.each do |loc|
      ssh_config = find_sshconfig_host_entry @ssh[loc][:addr], also_search_hostname: true
      ssh_addr = ssh_config.empty? ? @ssh[loc][:addr] : ssh_config['Hostname']
      ssh_port = @ssh[loc].keys.include?(:port) ? @ssh[loc][:port] : (ssh_config['Port'] || 22)
      if system("nc -z -G 1 -w 1 '#{ssh_addr}' '#{ssh_port}' &>/dev/null")
        @loc = loc
        @_host_available = true
        return true
      end
    end
    @_host_available = false
  end

  def host_status_message
    return @name.colorize(@highlight_color) + ' is in an ' + 'unknown'.colorize(:gray) + ' state. Please check for availability before using it.' if !defined?(@_host_available)
    return @name.colorize(@highlight_color) + ' is ' + "available #{@loc.to_s}ly".colorize(@highlight_color) + ' at ' + @ssh[@loc][:addr].colorize(@highlight_color) if @_host_available
    return @name.colorize(@highlight_color) + ' is ' + 'unreachable'.colorize(:red)
  end

  def find_sshconfig_host_entry host, also_search_hostname: false
    entries = get_sshconfig_host_entries
    entries.select{|e| e["Host"].include?(host) || (also_search_hostname && e["Hostname"] == host)}.first || []
  end

  def get_sshconfig_host_entries filename: nil
    #return @_all_ssh_host_entries if defined?(@_all_ssh_host_entries)
    filename ||= "~/.ssh/config"
    return [] unless File.exist?(File.expand_path(filename))
    ssh_config = File.read(File.expand_path(filename))
    entries = []
    buffer = []
    ssh_config.lines.map{|l| l.strip}.select{|l| !l.start_with?('#') && !l.chomp.empty?}.map{|l| l.strip}.each do |line|
      if m = line.match(/^Include (.*)$/)
        entries.push buffer; buffer = Array.new
        entries.concat Dir.glob(File.expand_path(m[1])).map{|included| get_sshconfig_host_entries(filename: included)}.flatten(1)
        next
      end
      if /^Host /.match(line) then entries.push buffer; buffer = Array.new end
      buffer.push line.split(' ', 2)
      if /^Host /.match(line) then buffer.last[1] = buffer.last[1].split(' ') end
    end
    entries.push(buffer)
    entries.reject!(&:empty?)
    entries.map{|e| e.to_h}
  end
end

class RemoteFolder < RemoteHost
  include FolderModule
  def initialize *params
    super **params.to_h
  end
end

class RemoteRemovableDisk < RemoteHost
  include RemovableDiskModule
  def initialize *params
    super **params.to_h
  end
end
###############
# Execution Tree Class
###############
class ExecutionNode
  def initialize node, locations, rsync_defaults
    node = {location: node} if node.is_a?(String)
    @host = locations[node[:location].to_sym]
    @execution_group = node[:execution_group] || nil
    @incoming = {
      source_folder_override: nil, dest_folder: '/', parallelize: false, rsync_options_merge: [], rsync_options_override: []
    }.merge((node[:incoming] || {}).compact)
    @outgoing = {
      source_folder: '/', exec_mode: nil, parallelize: false, rsync_options_merge: [], targets: [], failovers: []
    }.merge((node[:outgoing] || {}).compact)
    @outgoing[:targets].map!{|target| ExecutionNode.new(target, locations, rsync_defaults)}
    @outgoing[:failovers].map!{|target| ExecutionNode.new(target, locations, rsync_defaults)}
    @rsync_defaults = rsync_defaults || []
  end

  attr_reader :host, :execution_group, :incoming

  def backup exec_mode: 'fullsync', fsck_hosts: [], dryrun: false
    planned_targets = @outgoing[:targets].select{|target| target.host.available?}
    planned_failovers = @outgoing[:failovers].select{|target| target.host.available?}
    return false if !@host.available? || planned_targets.empty? && planned_failovers.empty?
    exec_mode = @outgoing[:exec_mode] || exec_mode
    backed_up_to_a_target = false

    perform_fsck = Proc.new { |node, highlight: false|
      System.log.debug "Host #{node.host.name.colorize(node.host.highlight_color)} #{node.host.available? && node.host.can_fsck? ? 'is' : 'is not'} configured for an fsck check.".colorize(highlight && node.host.highlight_color)
      if node.host.available? && node.host.can_fsck?
        if dryrun then System.log.info "Dry-run mode enabled. Skipping fsck check for #{node.host.name.colorize(node.host.highlight_color)}."; next end
        node.host.run_fsck!(highlight: highlight)
        node.host.fsck_status_handler(highlight: highlight)
      end
    }

    perform_backup = Proc.new { |target, highlight: false|
      System.log.debug "Entered backup execution mode: #{exec_mode} for #{@host.name} to target #{target.host.name}"
      next unless target.host.available?
      target.backup(exec_mode: 'shiftsync', fsck_hosts: fsck_hosts, dryrun: dryrun) if exec_mode == 'shiftsync'

      target.host.add_writer
      next unless target.host.available? # Check this again in case something happened while waiting for the lock or during shiftsync
      System.log.info backup_start_message_with_target(target, color: highlight && target.host.highlight_color)
      perform_fsck.call(target, highlight: highlight) if fsck_hosts.include?(target.host.name.downcase)
      executor = @host.is_a?(RemoteHost) && target.host.is_a?(LocalHost) ? target.host : @host
      rsync_string = build_rsync_string_with_target(target, executable: executor.rsync_executable_path, dryrun: dryrun)
      prefix_string = @host.name[0..2].colorize(@host.highlight_color) + '/' + target.host.name[0..2].colorize(target.host.highlight_color) + ' - '
      executor.run_command!(rsync_string, prefix: prefix_string, color: highlight && target.host.highlight_color)
      target.host.del_writer

      backed_up_to_a_target = true
      target.backup(exec_mode: 'fullsync', fsck_hosts: fsck_hosts, dryrun: dryrun) if exec_mode == 'fullsync'
    }

    System.log.info "Began backup process for #{@host.name.colorize(@host.highlight_color)} with planned targets #{planned_targets.map{|n| n.host.name.colorize(n.host.highlight_color)}.join(', ')}#{planned_failovers.empty? ? '' : ' and failovers ' + planned_failovers.map{|n| n.host.name.colorize(n.host.highlight_color)}.join(', ')}".colorize(mode: :bold)
    self.host.add_reader
    perform_fsck.call(self, highlight: @outgoing[:parallelize]) if fsck_hosts.include?(@host.name.downcase)
    if @outgoing[:parallelize]
      planned_targets.select{|target| target.host.available?(force_check: true)}.map{|target| Thread.new{ perform_backup.call(target, highlight: true) }}.each(&:join)
    else
      planned_targets.select{|target| target.host.available?(force_check: true)}.each{|target| perform_backup.call(target, highlight: true)}
    end
    if !backed_up_to_a_target && planned_failovers.count > 0
      System.log.warn "No primary targets have been backed up to for host #{@host.name}. Using available failovers."
      System.log.warn "As a precaution parallel execution will be disabled for these operations." if @outgoing[:parallelize]
      planned_failovers.select{|target| target.host.available?(force_check: true)}.each(&perform_backup)
    end
    self.host.del_reader
    backed_up_to_a_target
  end

  def show_full_tree from: nil, parent: nil, indents: [], failover: false, branch_char: nil, unavailable: false, show_legend: true, parallelize: false
    chars = { v: '│', m: '├', l: '└', h: '─' }
    if show_legend
      System.log.info "Legend:   #{chars[:h].colorize(:blue)} Primary Backup      #{chars[:h].colorize(:gray)} Non-executable Backup"
      System.log.info "          #{chars[:h].colorize(:red)} Failover Backup     * Parallelized backup"
    end

    unavailable = unavailable || !@host.available?
    hostcol = unavailable ? :gray : @host.highlight_color
    graphchar = chars[:h].colorize(unavailable ? :gray : failover ? :red : :blue)

    from = from.strip_color.colorize(:gray) if !from.nil? && unavailable
    to = "/#{@incoming[:dest_folder].sub(/^\//,'')}".colorize(hostcol)

    parts = Array.new()
    parts.push from.nil? ? indents.join : indents[0..-2].join
    parts.push from.nil? ? '' : "#{branch_char}#{graphchar} #{from} #{graphchar}#{graphchar} #{to} #{graphchar} "
    parts.push from.nil? ? @execution_group.nil? ? '   ' : (' ' * (3 - @execution_group.digits.count)) + @execution_group.to_s + ' ' : ''
    parts.push @host.name.colorize(hostcol)
    parts.push '*'.colorize(unavailable ? :gray : nil) if parallelize
    next_line_indent = ' ' * (parts.join.strip_color.length - (@host.name.length / 2))   #(@host.name.length / 2 + (from.nil? ? 0 : from.strip_color.length + to.strip_color.length + 9 ))
    #parts[4] = @outgoing[:targets].empty? ? '' : "\n" + indents.join + next_line_indent + "/#{@incoming[:dest_folder].sub(/^\//,'')}".colorize(hostcol)
    System.log.info parts.join

    targets_available = @outgoing[:targets].map{|t| t.host.available?}.reduce{|result, available| result || available}
    all = @outgoing[:targets] + @outgoing[:failovers]
    all.each_with_index do |t, i|
      t.show_full_tree(
        from: ('/' + (t.incoming[:source_folder_override] || @outgoing[:source_folder]).sub(/^\//,'')).colorize(@host.highlight_color),
        parent: self,
        indents: indents + [next_line_indent,
          t != all[-1] ? chars[:v].colorize(
            if @outgoing[:failovers].include?(all[i+1])
              unavailable || targets_available ? :gray : :red
            else
              unavailable || !targets_available ? :gray : :blue
            end
          ) : ' '],
        failover: @outgoing[:failovers].include?(t),
        branch_char: ((t == @outgoing[:targets][-1] && @outgoing[:failovers].empty?) ||
          (t == @outgoing[:failovers][-1]) ? chars[:l] : chars[:m]).colorize(
            if @outgoing[:failovers].include?(t)
              unavailable || targets_available ? :gray : :red
            else
              unavailable ? :gray : :blue
            end
          ),
        unavailable: unavailable || (@outgoing[:failovers].include?(t) && targets_available),
        show_legend: false,
        parallelize: @outgoing[:parallelize] && @outgoing[:targets].include?(t)
      )
    end
  end

  private

  def build_rsync_string_with_target target, executable: 'rsync', dryrun: false
    rsync_options = target.incoming[:rsync_options_override].empty? ? (@rsync_defaults + @outgoing[:rsync_options_merge] + target.incoming[:rsync_options_merge]) : target.incoming[:rsync_options_override]
    rsync_options = rsync_options.map{|opt| /^-[^-]+$/.match(opt) ? opt.chars[1..-1] : opt}.flatten.map{|opt| /^--[^-].+$/.match(opt) ? opt[2..-1] : opt}.uniq
    rsync_options = ['dry-run'] + (rsync_options - ['n', 'dry-run']) if dryrun
    System.log.debug "Dry run mode: #{dryrun}. Pre-processed rsync options: #{rsync_options}"
    rsync_options.concat(['.DocumentRevisions-V100', '.Spotlight-V100', '.TemporaryItems', '.Trashes', '.fseventsd', '.DS_Store', 'lost+found'].map{|xcl| "exclude #{xcl}"})
    rsync_options.uniq!
    short_opts = rsync_options.select{|opt| opt.length == 1}
    rsync_options = rsync_options.reject{|opt| opt.length == 1}.map{|opt| '--' + opt}
    rsync_options.unshift(short_opts.unshift('-').join) if short_opts.length > 0
    cmd = executable + ' ' + rsync_options.join(' ')

    num_remotes = [@host, target.host].map{|h| h.is_a?(RemoteHost)}.count(true)
    src_host, dest_host = @host, target.host
    if num_remotes == 2 && src_host.connection_parameters[:host] == dest_host.connection_parameters[:host]
      src_host = LocalHost.new(root: @host.connection_parameters[:root])
      dest_host = LocalHost.new(root: target.host.connection_parameters[:root])
    elsif num_remotes == 1
      remote_host = src_host.is_a?(RemoteHost) ? src_host : dest_host
      cmd += ' -e "ssh -Tx -o Compression=no'
      cmd += " -p #{remote_host.connection_parameters[:port]}" unless remote_host.connection_parameters[:port].nil?
      cmd += " -i '#{remote_host.connection_parameters[:keyfile]}'" unless remote_host.connection_parameters[:keyfile].nil?
      cmd += '"'
    end
    [[src_host, target.incoming[:source_folder_override] || @outgoing[:source_folder]], [dest_host, target.incoming[:dest_folder]]].each do |host, subfolder|
      cmd += ' "'
      cmd += host.connection_parameters[:user] + '@' if !host.connection_parameters[:user].nil? && !host.connection_parameters[:host].nil?
      cmd += host.connection_parameters[:host] + ':' if !host.connection_parameters[:host].nil?
      cmd += File.join(host.connection_parameters[:root], subfolder, '') + '"'
    end
    cmd
  end

  def backup_start_message_with_target target, color: :default
    msg = "Backing up #{@host.name.colorize(@host.highlight_color)} to #{target.host.name.colorize(target.host.highlight_color)} "
    if [@host, target.host].map{|h| h.is_a?(RemoteHost)}.count(true) == 0
      msg += 'locally...'
    else
      lan_locs = [@host, target.host].select{|h| h.is_a?(RemoteHost) && h.loc == :local}
      wan_locs = [@host, target.host].select{|h| h.is_a?(RemoteHost) && h.loc == :remote}
      msg += 'over the ' + (wan_locs.length > 0 ? 'internet'.colorize(wan_locs.last.highlight_color) : 'local network'.colorize(lan_locs.last.highlight_color))
      msg += '...'
    end
    msg += " (Parallelized output will be colored)".colorize(color) unless color == :default || color.nil?
    msg
  end
end
###############
# Config Storage Class
###############
class Config < Hash
  def self.skeleton
    skelfile = File.join(File.dirname(__FILE__), 'example.yaml')
    begin
      File.read(skelfile)
    rescue Errno::ENOENT
      System.debug "Could not load skeleton config at the following location. Failing over to the hardcoded base64 schema: '#{schemafile}'"
      "eJyVWNFuG7sRffdXEMmDbcCSEjuOE6EokN40uBfIbYrrpECfHO4uV2LNJVWS\nK1t5uN/eM0Nyd6XIBioghrIiOTNnzpwZ7mw2OzGullE7G5biyc9LcfaH+m+v\nvWrOxUfVaqtEXCsx7MX/ZORH0Tkjwtr1phGVrO9Fv8EzIW2zcF603nUnQvzq\nOiU+OdMovzwhA965uBSLNZ4vul0flOfHa71aG/yLd7Uzzi/Fyitl8dNtdF6u\nlPjo9VbtHdHZuAjpV37c6HC/FNH36snQvmwoBmnOxScjV4hCIx7pVyoKGYQU\nXnVuKyujxFr6RjRkU7SIpnNeCVnXvZcRX7ZSG1lpo+NONCqqmo6di1+kFdIE\nYNBH1wGvWhqzE1vldbsbgaud99giNtJr2ii+ffvto4ArnettVI04Czsb5aOo\nlHEP58fx2SmDH/Hb3wA9kL9VHnaOZnYvp/+QSIhrUwY59ENMq3TgM2f8U8Z1\nOSOvpv18UAjrZ+h1kIXf0hm3t7+KCgy7JxAaJl1zMfGQHkevJGEz5Al5CBzz\nSTq4hmvKRo0EHHHgJf0hO7+My+bi364XndyJcK83ZC8oodmlnZBIeHZFaCv+\nXMwR2aJ2ttWrk3Iq0Xcp1KPsNkYNT+/VrtVGLcsm3dz5IPPPVEjmSYReiq9r\niitGbVeBqYe46zX+l9iaQhYgTalKI6yKD87fzwnOysX14IhsGrj3+v3l/PXb\nd/PX89evDgDJB6BkC6STsC8mJhC3TSwXD9oYMFPIGFW3QUoGcxvnwaHLy+OB\n0afVPkQ2R0dnk+VAgJnT26JsiFdz8SEKoyT2OFvwTbueQjDZSdxENgGM6Hrs\nrybZbGGKAAUd5gdYdbv5pq+MrueNDfOaJWw/uInUPP3ZI/lHFfTKsm5kRUGQ\no9IQGmGjapIISZoQkyhASlkPRFaNFXZarrM5SEJqAeKy2gQN+u0oRBCH9p2S\nCJ4KkOcUUAZ8jcOqeq1QZ6xFkuOg4tp4gGVjDpbVi0wvBW8/hvCHPYVLjpKX\no/+AWXPltvixmUOg2Ld0Ir5kVXTW7ObUaWRvIi0uPmdn+l43S/FWtVV7/f5m\n9v7VqzezNzdK4dvby9n1K3VzdVXfXDaXklz7lzM99I0FlWOEffUIdFk6kovs\n7MZpy0CqvT01FLxSyWVR7YTvrSWqfA9946BR97oRi0ZtF3/BH12rv36nUjTa\n9o8E93cCtI/aQDIQyc8rf5f1l1vGIg4lvZWmz1WgbOi9GjvF4Po2+Ug6iMco\nhtIrLpg/TINSQiQaQwphpeijtHdtqO+PJjVnlfUYRlhoOF3EJBYCFD79IfOh\n9nrD0AIeOI5mQI+/z2Z0/neIRdeRV4aGBxACHScqT54KWpApWMp+ozw87uB4\npVpus3aXuwo153usMLJWx7tgh+aPVnm07n4ti/f6vLa5BycfXR83PYjwCaDx\nmcLxAeECCEBl1jFuwnKxWCHKviJFWLTyh66U9Ater3+oBXpXtXjX1LV628j6\n8ubd9bV6jS9Xsrm+endVyeu36vL6DWh78+5qYXQ1bq2NDOEOAK1dE+a+evn5\n+kQ9qronJ+7Q9J5QuoM5jVJSqcyZvBs4S20vku4R29buYdKyA2s9UuxorMma\nolN3xYNAQkX25+LvaEAZPgSvjaMOZF3DfNTcTalH4CiNCkbCk5TMhqFxmcbA\nlsfAp4JgfZhMmsxjekCWOPsjLivv+s1SvDrEBJ8JAb7CexbMUOo6nZA6OhHT\nGGWozPm8VJCqQyCIdA1PIRGQoxFQXhZO5+KzeyAI+q5S8D0/Hxg9WOF2hyYG\nQic3uLAbZ08jBsxtKuSk/RrLy36qqgBc0pgCeS1qQDL6xdJEKQ2EKA8BdDSD\nlJoZGL2CuK2e7ZAT3L9yoyQuDKUaKJfU4jcbQ46RDpDs5JMFxtNanEEPWKtA\ngiFnWaCC632tzrPyEB53HRyE9PTG8O5D5cEnJS7R8kVZ+EKcNak3nLPSvQhr\n3Ub+BUVbTmPk7pXaQAlpHgqEfmLshKHQ3bI57cjSs1cUYIZXIHiA7NGJFG+j\n21YRq8UL+oW8fFHm30bGMtoVRqGuj9xDhjj/6C27OcBZTNOVKeGZimvC0bMO\nCOhZXGMabJA1kApqEzhRPFOEBD39PAuyTWMFprboHQ5okkrTiA1hq3rq/R6i\nSiua1K6pQkLMDKzzsK33ZnznqXy5N9iAXVtVxqeU77tU4LhGHGEcfW77KmuA\nV0ZGVphErc+FQEzmMqnJClJTxj5K210WZwgmcosB+ycTH5oUD/Qor81c5tbI\nKPBJrC5DBqKXNiDFIRvL1HmihA4r6DQvPy30N5om1oTdxutO+tLRysnzXHY0\nnmjWGro6eo+RDvtC9Dz+nwF/64ZArEq1mAa982E0nQrt3nV5CgyF2wpX/QcD\nRaAJFDf3ByuohkftB0goPLLBvWOfmSRWQ6HnvFn1GE9GZLRFgzyqPezHUakp\nMl/2Dsko9aBySxmMn0wP3qPeHbUmr0lpFiLdpuhG6RRNgbKOkM4HngqjCHKH\nLHxLAafRxu/YvBveZox1n44PJamBLtFplqcCHJaNb0kmxbvnbgNtGuuE3oIc\n1oiKiUS0UtvSCrlqClSZSxmvA5gufiouMy2uPW+eL6rBM5qSCwnHdsXyX3oW\n723GYbApAz3NkbhebLXrg9k9Y31M3Z//n/Wy8Tm784PR9oIvyvs7yrU0h1JM\nno02WY/OmcC40WFWbSbxDH13L8aiJHsPqWT3XttMiyQVCtys+c1aGe2ldawT\nubmlQobSYD7W8TQMySdx5xmXTpAotweVJ44iH4QMzdg5wOxZGeyOi97haPWp\njIHpfURq2kRLmEivAbVN5qcaOL7NQTDlLZpR6RpGnThd2PZGyvEtUDgqeHs4\nTlD+udBOEt9Kvp+cq6c39+H9Z95V7g0zvtvsd5gNJvmEMBu6mN5nMGnMcvTD\nyx2CbOTWWdLjRDGenmdyu/5x1MkpW4abM+xipiRBmLSMoNIk3igDtZ1lj546\ni5on9iN1s1njdzMaRLnOWHhYj1Yle1bR/EFZRZOi0PPOyeVqNl4AofRihiCH\nc8+T5ub79f8AH14y9g==\n".decompress ##REPLACE#SKELFILE##
    end
  end
  
  def initialize locations_arr = []
    @location = nil
    @validation_msg = nil
    config = nil
    locations_arr.map{ |filepath| File.expand_path(filepath) }.each do |filepath|
      begin
        config = YAML.safe_load_file(filepath, symbolize_names: true, aliases: true)
        System.log.debug "Loaded valid YAML config file at '#{filepath}'"
        @location = filepath
        break
      rescue Errno::ENOENT
        System.log.debug "Attempted to load YAML config file but did not find it at: '#{filepath}'"
      rescue Psych::SyntaxError => e
        System.log.warn "Invalid YAML syntax found at '#{filepath}'"
        System.log.warn e.message
      end
    end
    config.keys.each{|k| self[k] = config[k]} unless config.nil?
    super
  end

  def validate!
    schemafile = File.join(File.dirname(__FILE__), 'backupchain.schema.yaml')
    schema = nil
    begin
      schema = YAML.safe_load_file(schemafile)
      System.log.debug "Loaded config schema file from '#{schemafile}'"
    rescue Errno::ENOENT
      System.debug "Could not load schemafile at the following location. Failing over to the hardcoded base64 schema: '#{schemafile}'"
      schema = YAML.safe_load "eJzVV0tv2zgQvvtXEGoOSVaK0nSTgy4LtHtZIMD20FtgG7Q0klhTpJYcNfVi\nf/ySeliWTMlO2qK7AgyTnOHMNw8OOUEQLLwLlngRyRFLHYUh3eayUruHcEPj\nbZxTJm50nENBbz5rKRZhSLyLZuFgkyUFLZtUWZgommJ4d3t3G7y9CxvCAhly\niMj7Ti75IEXKskpRZEYy7kpDlZvPEONCwV8VU5BE5InLuGbQPoGvEFd2vEYF\nsFzQJGF2SvlHJUtQyEBHJKVcw6LsVxaEKL0T8TqBlFYc6xVi7FCQGiO8N+GF\noeiwZpIlas/Q92ob5gR0rFhpVyLyyDQSmRLroqokSFUGqAlKooEb+CRVsiBU\nJARzYMqsIjKR6VrSwE67UFJEUOLjAHAN8Oba68Y9AgvgfaP4U62YPLZQye+Q\nMlF7ZL/rSJv9DryrpMTlnjDn0I6nPMJZizRyDuedZo3KWD4gtPZGZHV5+Vv0\ntAqX1+HV9dXlzfXVxQFjwvR2KFEK+DMdLhEStIo2UnKgYoI6csCsxGbfgY9o\nhbKQlUCfVBVLlg7+81w38ILTjQOJndopBjJrev/FJosxIqgqNxRSm3VKiyOS\nh18qVUGNFitqgimmYp3qePt6e4Kf4+bJNOlxnRcJ+7XRmIY8FHnC7YcSNdLN\n/zTAOctybn64jiWX6sxKAqIqzPnccFMOfXNiE59k5mIQPtkB5/LZJxtegU8K\nmoFA6pN4Rw3xOWdoVtvbwCeN4lZKM6llNcNWYjPp5HZbrPRmvNfRmlFrasat\nvkzRXQ1wd1hBtM5d1joK1rmpT8XOVSZHVyofl7EBh4JCIgxZpo9SbDYZ45mB\nchz62QL8kuPstOsIeaVBuSr0gGkLu5RxOOabLxdWtju3T5ygVt+r9p59Yc68\nJLrPW13Wsf+nie/VhffCeB3eiknicPRLAjrvbCv/lQ5rS9VEFTpRzQPCyi+/\nzpMfZsi51ChoMV3bjYREBDNspVQT4BvLmUDIQDk5CvMALGxVvHWT6deG/HB/\n/+5+MSCsMVdAE/2dy9F0lK22qfybsnFv39sR6VmZIvtN0obdhePZ/ykHe9f2\nPYvtAXL5bB/+TUdz1BCYv7zV2yChytwC9dzALfqn/rgX6cEImYBnujS77O17\nGdumTED88PgHkfW8bklKquv/ettpJI7Dta8/3uppFSx/8QbOsvgid2dzKkWO\nU6PruvpAOvD0ujMlq3LMOw6240jsj8HdfXcImPGp4czG0kaZ//oOSZu2OoZ1\nKnkCai2/gFIsGWXsbIdzVPBM5LGV931br6ZbbnNoXYDJ5qGCiSfGfEftsklU\nnE8qdvvoR+iWFWbyRwbfpuy6kGNbTr1sUwPRmuETnbMU7XA5lVJnSS6popwD\nZ387kRw/zH9aKrQ11IWyr1zdN6hgs8hONlYO6ONa3DOnlHGbpf9JmP8C8dkT\nCQ==\n".decompress ##REPLACE#SCHEMAFILE##
    end
    begin
      JSON::Validator.validate!(schema, self)
    rescue JSON::Schema::ValidationError => e
      @validation_msg = JSON::Validator.fully_validate(schema, self)
      return false
    end
    return true
  end

  def validation_errors
    return @validation_msg
  end
end
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
      'FATAL' => {background: :red},
      'ANY' => :default
    }

    @logger.formatter = proc do |severity, time, progname, msg|
      #original_formatter.call(severity, time, progname, msg.dump)
      msg.lines.map{|m|
        if fmt == :standard
          "[#{time.strftime("%Y-%m-%d %H:%M:%S.%6N")}] #{progname} || #{severity + (' ' * (5 - severity.length))} || #{m.strip_color}"  # Strips color from the message
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


# This file pulled and modified from https://github.com/ManageIQ/optimist/blob/30b3b84af5d9af3f577e3bac9c02e9600dc80c64/lib/optimist.rb

# lib/optimist.rb -- optimist command-line processing library
# Copyright (c) 2008-2014 William Morgan.
# Copyright (c) 2014 Red Hat, Inc.
# optimist is licensed under the MIT license.

require 'date'

module Optimist
VERSION = "3.1.0"

## Thrown by Parser in the event of a commandline error. Not needed if
## you're using the Optimist::options entry.
class CommandlineError < StandardError
  attr_reader :error_code

  def initialize(msg, error_code = nil)
    super(msg)
    @error_code = error_code
  end
end

## Thrown by Parser if the user passes in '-h' or '--help'. Handled
## automatically by Optimist#options.
class HelpNeeded < StandardError
end

## Thrown by Parser if the user passes in '-v' or '--version'. Handled
## automatically by Optimist#options.
class VersionNeeded < StandardError
end

## Regex for floating point numbers
FLOAT_RE = /^-?((\d+(\.\d+)?)|(\.\d+))([eE][-+]?[\d]+)?$/

## Regex for parameters
PARAM_RE = /^-(-|\.$|[^\d\.])/

## The commandline parser. In typical usage, the methods in this class
## will be handled internally by Optimist::options. In this case, only the
## #opt, #banner and #version, #depends, and #conflicts methods will
## typically be called.
##
## If you want to instantiate this class yourself (for more complicated
## argument-parsing logic), call #parse to actually produce the output hash,
## and consider calling it from within
## Optimist::with_standard_exception_handling.
class Parser

  ## The registry is a class-instance-variable map of option aliases to their subclassed Option class.
  @registry = {}

  ## The Option subclasses are responsible for registering themselves using this function.
  def self.register(lookup, klass)
    @registry[lookup.to_sym] = klass
  end

  ## Gets the class from the registry.
  ## Can be given either a class-name, e.g. Integer, a string, e.g "integer", or a symbol, e.g :integer
  def self.registry_getopttype(type)
    return nil unless type
    if type.respond_to?(:name)
      type = type.name
      lookup = type.downcase.to_sym
    else
      lookup = type.to_sym
    end
    raise ArgumentError, "Unsupported argument type '#{type}', registry lookup '#{lookup}'" unless @registry.has_key?(lookup)
    return @registry[lookup].new
  end

  INVALID_SHORT_ARG_REGEX = /[\d-]/ #:nodoc:

  ## The values from the commandline that were not interpreted by #parse.
  attr_reader :leftovers

  ## The complete configuration hashes for each option. (Mainly useful
  ## for testing.)
  attr_reader :specs

  ## A flag that determines whether or not to raise an error if the parser is passed one or more
  ##  options that were not registered ahead of time.  If 'true', then the parser will simply
  ##  ignore options that it does not recognize.
  attr_accessor :ignore_invalid_options

  ## Initializes the parser, and instance-evaluates any block given.
  def initialize(*a, &b)
    @version = nil
    @leftovers = []
    @specs = {}
    @long = {}
    @short = {}
    @order = []
    @constraints = []
    @stop_words = []
    @stop_on_unknown = false
    @educate_on_error = false
    @synopsis = nil
    @usage = nil

    # instance_eval(&b) if b # can't take arguments
    cloaker(&b).bind(self).call(*a) if b
  end

  ## Define an option. +name+ is the option name, a unique identifier
  ## for the option that you will use internally, which should be a
  ## symbol or a string. +desc+ is a string description which will be
  ## displayed in help messages.
  ##
  ## Takes the following optional arguments:
  ##
  ## [+:long+] Specify the long form of the argument, i.e. the form with two dashes. If unspecified, will be automatically derived based on the argument name by turning the +name+ option into a string, and replacing any _'s by -'s.
  ## [+:short+] Specify the short form of the argument, i.e. the form with one dash. If unspecified, will be automatically derived from +name+. Use :none: to not have a short value.
  ## [+:type+] Require that the argument take a parameter or parameters of type +type+. For a single parameter, the value can be a member of +SINGLE_ARG_TYPES+, or a corresponding Ruby class (e.g. +Integer+ for +:int+). For multiple-argument parameters, the value can be any member of +MULTI_ARG_TYPES+ constant. If unset, the default argument type is +:flag+, meaning that the argument does not take a parameter. The specification of +:type+ is not necessary if a +:default+ is given.
  ## [+:default+] Set the default value for an argument. Without a default value, the hash returned by #parse (and thus Optimist::options) will have a +nil+ value for this key unless the argument is given on the commandline. The argument type is derived automatically from the class of the default value given, so specifying a +:type+ is not necessary if a +:default+ is given. (But see below for an important caveat when +:multi+: is specified too.) If the argument is a flag, and the default is set to +true+, then if it is specified on the the commandline the value will be +false+.
  ## [+:required+] If set to +true+, the argument must be provided on the commandline.
  ## [+:multi+] If set to +true+, allows multiple occurrences of the option on the commandline. Otherwise, only a single instance of the option is allowed. (Note that this is different from taking multiple parameters. See below.)
  ##
  ## Note that there are two types of argument multiplicity: an argument
  ## can take multiple values, e.g. "--arg 1 2 3". An argument can also
  ## be allowed to occur multiple times, e.g. "--arg 1 --arg 2".
  ##
  ## Arguments that take multiple values should have a +:type+ parameter
  ## drawn from +MULTI_ARG_TYPES+ (e.g. +:strings+), or a +:default:+
  ## value of an array of the correct type (e.g. [String]). The
  ## value of this argument will be an array of the parameters on the
  ## commandline.
  ##
  ## Arguments that can occur multiple times should be marked with
  ## +:multi+ => +true+. The value of this argument will also be an array.
  ## In contrast with regular non-multi options, if not specified on
  ## the commandline, the default value will be [], not nil.
  ##
  ## These two attributes can be combined (e.g. +:type+ => +:strings+,
  ## +:multi+ => +true+), in which case the value of the argument will be
  ## an array of arrays.
  ##
  ## There's one ambiguous case to be aware of: when +:multi+: is true and a
  ## +:default+ is set to an array (of something), it's ambiguous whether this
  ## is a multi-value argument as well as a multi-occurrence argument.
  ## In thise case, Optimist assumes that it's not a multi-value argument.
  ## If you want a multi-value, multi-occurrence argument with a default
  ## value, you must specify +:type+ as well.

  def opt(name, desc = "", opts = {}, &b)
    opts[:callback] ||= b if block_given?
    opts[:desc] ||= desc

    o = Option.create(name, desc, opts)

    raise ArgumentError, "you already have an argument named '#{name}'" if @specs.member? o.name
    raise ArgumentError, "long option name #{o.long.inspect} is already taken; please specify a (different) :long" if @long[o.long]
    raise ArgumentError, "short option name #{o.short.inspect} is already taken; please specify a (different) :short" if @short[o.short]
    raise ArgumentError, "permitted values for option #{o.long.inspect} must be either nil or an array;" unless o.permitted.nil? or o.permitted.is_a? Array
    @long[o.long] = o.name
    @short[o.short] = o.name if o.short?
    @specs[o.name] = o
    @order << [:opt, o.name]
  end

  ## Sets the version string. If set, the user can request the version
  ## on the commandline. Should probably be of the form "<program name>
  ## <version number>".
  def version(s = nil)
    s ? @version = s : @version
  end

  ## Sets the usage string. If set the message will be printed as the
  ## first line in the help (educate) output and ending in two new
  ## lines.
  def usage(s = nil)
    s ? @usage = s : @usage
  end

  ## Adds a synopsis (command summary description) right below the
  ## usage line, or as the first line if usage isn't specified.
  def synopsis(s = nil)
    s ? @synopsis = s : @synopsis
  end

  ## Adds text to the help display. Can be interspersed with calls to
  ## #opt to build a multi-section help page.
  def banner(s)
    @order << [:text, s]
  end
  alias_method :text, :banner

  ## Marks two (or more!) options as requiring each other. Only handles
  ## undirected (i.e., mutual) dependencies. Directed dependencies are
  ## better modeled with Optimist::die.
  def depends(*syms)
    syms.each { |sym| raise ArgumentError, "unknown option '#{sym}'" unless @specs[sym] }
    @constraints << [:depends, syms]
  end

  ## Marks two (or more!) options as conflicting.
  def conflicts(*syms)
    syms.each { |sym| raise ArgumentError, "unknown option '#{sym}'" unless @specs[sym] }
    @constraints << [:conflicts, syms]
  end

  ## Marks two (or more!) options as required but mutually exclusive.
  def either(*syms)
    syms.each { |sym| raise ArgumentError, "unknown option '#{sym}'" unless @specs[sym] }
    @constraints << [:conflicts, syms]
    @constraints << [:either, syms]
  end

  ## Defines a set of words which cause parsing to terminate when
  ## encountered, such that any options to the left of the word are
  ## parsed as usual, and options to the right of the word are left
  ## intact.
  ##
  ## A typical use case would be for subcommand support, where these
  ## would be set to the list of subcommands. A subsequent Optimist
  ## invocation would then be used to parse subcommand options, after
  ## shifting the subcommand off of ARGV.
  def stop_on(*words)
    @stop_words = [*words].flatten
  end

  ## Similar to #stop_on, but stops on any unknown word when encountered
  ## (unless it is a parameter for an argument). This is useful for
  ## cases where you don't know the set of subcommands ahead of time,
  ## i.e., without first parsing the global options.
  def stop_on_unknown
    @stop_on_unknown = true
  end

  ## Instead of displaying "Try --help for help." on an error
  ## display the usage (via educate)
  def educate_on_error
    @educate_on_error = true
  end

  ## Parses the commandline. Typically called by Optimist::options,
  ## but you can call it directly if you need more control.
  ##
  ## throws CommandlineError, HelpNeeded, and VersionNeeded exceptions.
  def parse(cmdline = ARGV)
    vals = {}
    required = {}

    opt :version, "Print version and exit" if @version && ! (@specs[:version] || @long["version"])
    opt :help, "Show this message" unless @specs[:help] || @long["help"]

    @specs.each do |sym, opts|
      required[sym] = true if opts.required?
      vals[sym] = opts.default
      vals[sym] = [] if opts.multi && !opts.default && !opts.flag? # multi arguments default to [], not nil
      vals[sym] = 0 if opts.multi && !opts.default && opts.flag? # multi argument flags default to 0 because they return a count
    end

    resolve_default_short_options!

    ## resolve symbols
    given_args = {}
    @leftovers = each_arg cmdline do |arg, params|
      ## handle --no- forms
      arg, negative_given = if arg =~ /^--no-([^-]\S*)$/
        ["--#{$1}", true]
      else
        [arg, false]
      end

      sym = case arg
        when /^-([^-])$/      then @short[$1]
        when /^--([^-]\S*)$/  then @long[$1] || @long["no-#{$1}"]
        else                       raise CommandlineError, "invalid argument syntax: '#{arg}'"
      end

      sym = nil if arg =~ /--no-/ # explicitly invalidate --no-no- arguments

      next nil if ignore_invalid_options && !sym
      raise CommandlineError, "unknown argument '#{arg}'" unless sym

      if given_args.include?(sym) && !@specs[sym].multi?
        raise CommandlineError, "option '#{arg}' specified multiple times"
      end

      given_args[sym] ||= {}
      given_args[sym][:arg] = arg
      given_args[sym][:negative_given] = negative_given
      given_args[sym][:params] ||= []

      # The block returns the number of parameters taken.
      num_params_taken = 0

      if @specs[sym].multi? && @specs[sym].flag?
        given_args[sym][:params][0] ||= 0
        given_args[sym][:params][0] += 1
      end

      unless params.empty?
        if @specs[sym].single_arg?
          given_args[sym][:params] << params[0, 1]  # take the first parameter
          num_params_taken = 1
        elsif @specs[sym].multi_arg?
          given_args[sym][:params] << params        # take all the parameters
          num_params_taken = params.size
        end
      end

      num_params_taken
    end

    ## check for version and help args
    raise VersionNeeded if given_args.include? :version
    raise HelpNeeded if given_args.include? :help

    ## check constraint satisfaction
    @constraints.each do |type, syms|
      constraint_sym = syms.find { |sym| given_args[sym] }

      case type
      when :depends
        next unless constraint_sym
        syms.each { |sym| raise CommandlineError, "--#{@specs[constraint_sym].long} requires --#{@specs[sym].long}" unless given_args.include? sym }
      when :conflicts
        next unless constraint_sym
        syms.each { |sym| raise CommandlineError, "--#{@specs[constraint_sym].long} conflicts with --#{@specs[sym].long}" if given_args.include?(sym) && (sym != constraint_sym) }
      when :either
        raise CommandlineError, "one of #{syms.map { |sym| "--#{@specs[sym].long}" }.join(', ') } is required" if (syms & given_args.keys).size != 1
      end
    end

    required.each do |sym, val|
      raise CommandlineError, "option --#{@specs[sym].long} must be specified" unless given_args.include? sym
    end

    ## parse parameters
    given_args.each do |sym, given_data|
      arg, params, negative_given = given_data.values_at :arg, :params, :negative_given

      opts = @specs[sym]
      if params.empty? && !opts.flag?
        raise CommandlineError, "option '#{arg}' needs a parameter" unless opts.default
        params << (opts.array_default? ? opts.default.clone : [opts.default])
      end

      params[0].each do |p|
        raise CommandlineError, "option '#{arg}' only accepts one of: #{opts.permitted.join(', ')}" unless opts.permitted.include? p
      end unless opts.permitted.nil?

      vals["#{sym}_given".intern] = true # mark argument as specified on the commandline

      vals[sym] = opts.parse(params, negative_given)

      if opts.single_arg?
        if opts.multi?        # multiple options, each with a single parameter
          vals[sym] = vals[sym].map { |p| p[0] }
        else                  # single parameter
          vals[sym] = vals[sym][0][0]
        end
      elsif opts.multi_arg? && !opts.multi?
        vals[sym] = vals[sym][0]  # single option, with multiple parameters
      end
      # else: multiple options, with multiple parameters

      opts.callback.call(vals[sym]) if opts.callback
    end

    ## modify input in place with only those
    ## arguments we didn't process
    cmdline.clear
    @leftovers.each { |l| cmdline << l }

    ## allow openstruct-style accessors
    class << vals
      def method_missing(m, *_args)
        self[m] || self[m.to_s]
      end
    end
    vals
  end

  ## Print the help message to +stream+.
  def educate(stream = $stdout)
    width # hack: calculate it now; otherwise we have to be careful not to
          # call this unless the cursor's at the beginning of a line.

    left = {}
    @specs.each { |name, spec| left[name] = spec.educate }

    leftcol_width = left.values.map(&:length).max || 0
    rightcol_start = leftcol_width + 6 # spaces

    unless @order.size > 0 && @order.first.first == :text
      command_name = File.basename($0).gsub(/\.[^.]+$/, '')
      stream.puts "Usage: #{command_name} #{@usage}\n" if @usage
      stream.puts "#{@synopsis}\n" if @synopsis
      stream.puts if @usage || @synopsis
      stream.puts "#{@version}\n" if @version
      stream.puts "Options:"
    end

    @order.each do |what, opt|
      if what == :text
        stream.puts wrap(opt)
        next
      end

      spec = @specs[opt]
      stream.printf "  %-#{leftcol_width}s    ", left[opt]
      desc = spec.full_description

      stream.puts wrap(desc, :width => width - rightcol_start - 1, :prefix => rightcol_start)
    end
  end

  def width #:nodoc:
    @width ||= if $stdout.tty?
      begin
        require 'io/console'
        w = IO.console.winsize.last
        w.to_i > 0 ? w : 80
      rescue LoadError, NoMethodError, Errno::ENOTTY, Errno::EBADF, Errno::EINVAL
        legacy_width
      end
    else
      80
    end
  end

  def legacy_width
    # Support for older Rubies where io/console is not available
    `tput cols`.to_i
  rescue Errno::ENOENT
    80
  end
  private :legacy_width

  def wrap(str, opts = {}) # :nodoc:
    if str == ""
      [""]
    else
      inner = false
      str.split("\n").map do |s|
        line = wrap_line s, opts.merge(:inner => inner)
        inner = true
        line
      end.flatten
    end
  end

  ## The per-parser version of Optimist::die (see that for documentation).
  def die(arg, msg = nil, error_code = nil)
    msg, error_code = nil, msg if msg.kind_of?(Integer)
    if msg
      $stderr.puts "Error: argument --#{@specs[arg].long} #{msg}."
    else
      $stderr.puts "Error: #{arg}."
    end
    if @educate_on_error
      $stderr.puts
      educate $stderr
    else
      $stderr.puts "Try --help for help."
    end
    exit(error_code || -1)
  end

private

  ## yield successive arg, parameter pairs
  def each_arg(args)
    remains = []
    i = 0

    until i >= args.length
      return remains += args[i..-1] if @stop_words.member? args[i]
      case args[i]
      when /^--$/ # arg terminator
        return remains += args[(i + 1)..-1]
      when /^--(\S+?)=(.*)$/ # long argument with equals
        num_params_taken = yield "--#{$1}", [$2]
        if num_params_taken.nil?
          remains << args[i]
          if @stop_on_unknown
            return remains += args[i + 1..-1]
          end
        end
        i += 1
      when /^--(\S+)$/ # long argument
        params = collect_argument_parameters(args, i + 1)
        num_params_taken = yield args[i], params

        if num_params_taken.nil?
          remains << args[i]
          if @stop_on_unknown
            return remains += args[i + 1..-1]
          end
        else
          i += num_params_taken
        end
        i += 1
      when /^-(\S+)$/ # one or more short arguments
        short_remaining = ""
        shortargs = $1.split(//)
        shortargs.each_with_index do |a, j|
          if j == (shortargs.length - 1)
            params = collect_argument_parameters(args, i + 1)

            num_params_taken = yield "-#{a}", params
            unless num_params_taken
              short_remaining << a
              if @stop_on_unknown
                remains << "-#{short_remaining}"
                return remains += args[i + 1..-1]
              end
            else
              i += num_params_taken
            end
          else
            unless yield "-#{a}", []
              short_remaining << a
              if @stop_on_unknown
                short_remaining += shortargs[j + 1..-1].join
                remains << "-#{short_remaining}"
                return remains += args[i + 1..-1]
              end
            end
          end
        end

        unless short_remaining.empty?
          remains << "-#{short_remaining}"
        end
        i += 1
      else
        if @stop_on_unknown
          return remains += args[i..-1]
        else
          remains << args[i]
          i += 1
        end
      end
    end

    remains
  end

  def collect_argument_parameters(args, start_at)
    params = []
    pos = start_at
    while args[pos] && args[pos] !~ PARAM_RE && !@stop_words.member?(args[pos]) do
      params << args[pos]
      pos += 1
    end
    params
  end

  def resolve_default_short_options!
    @order.each do |type, name|
      opts = @specs[name]
      next if type != :opt || opts.short

      c = opts.long.split(//).find { |d| d !~ INVALID_SHORT_ARG_REGEX && !@short.member?(d) }
      if c # found a character to use
        opts.short = c
        @short[c] = name
      end
    end
  end

  def wrap_line(str, opts = {})
    prefix = opts[:prefix] || 0
    width = opts[:width] || (self.width - 1)
    start = 0
    ret = []
    until start > str.length
      nextt =
        if start + width >= str.length
          str.length
        else
          x = str.rindex(/\s/, start + width)
          x = str.index(/\s/, start) if x && x < start
          x || str.length
        end
      ret << ((ret.empty? && !opts[:inner]) ? "" : " " * prefix) + str[start...nextt]
      start = nextt + 1
    end
    ret
  end

  ## instance_eval but with ability to handle block arguments
  ## thanks to _why: http://redhanded.hobix.com/inspect/aBlockCostume.html
  def cloaker(&b)
    (class << self; self; end).class_eval do
      define_method :cloaker_, &b
      meth = instance_method :cloaker_
      remove_method :cloaker_
      meth
    end
  end
end

class Option

  attr_accessor :name, :short, :long, :default, :permitted
  attr_writer :multi_given

  def initialize
    @long = nil
    @short = nil
    @name = nil
    @multi_given = false
    @hidden = false
    @default = nil
    @permitted = nil
    @optshash = Hash.new()
  end

  def opts(key)
    @optshash[key]
  end

  def opts=(o)
    @optshash = o
  end

  ## Indicates a flag option, which is an option without an argument
  def flag? ; false ; end
  def single_arg?
    !self.multi_arg? && !self.flag?
  end

  def multi ; @multi_given ; end
  alias multi? multi

  ## Indicates that this is a multivalued (Array type) argument
  def multi_arg? ; false ; end
  ## note: Option-Types with both multi_arg? and flag? false are single-parameter (normal) options.

  def array_default? ; self.default.kind_of?(Array) ; end

  def short? ; short && short != :none ; end

  def callback ; opts(:callback) ; end
  def desc ; opts(:desc) ; end

  def required? ; opts(:required) ; end

  def parse(_paramlist, _neg_given)
    raise NotImplementedError, "parse must be overridden for newly registered type"
  end

  # provide type-format string.  default to empty, but user should probably override it
  def type_format ; "" ; end

  def educate
    (short? ? "-#{short}, " : "    ") + "--#{long}" + type_format + (flag? && default ? ", --no-#{long}" : "")
  end

  ## Format the educate-line description including the default and permitted value(s)
  def full_description
    desc_str = desc
    desc_str += default_description_str(desc) if default
    desc_str += permitted_description_str(desc) if permitted
    desc_str
  end

  ## Generate the default value string for the educate line
  private def default_description_str str
    default_s = case default
                when $stdout   then '<stdout>'
                when $stdin    then '<stdin>'
                when $stderr   then '<stderr>'
                when Array
                  default.join(', ')
                else
                  default.to_s
                end
    defword = str.end_with?('.') ? 'Default' : 'default'
    " (#{defword}: #{default_s})"
  end

  ## Generate the permitted values string for the educate line
  private def permitted_description_str str
    permitted_s = permitted.map do |p|
      case p
      when $stdout   then '<stdout>'
      when $stdin    then '<stdin>'
      when $stderr   then '<stderr>'
      else
        p.to_s
      end
    end.join(', ')
    permword = str.end_with?('.') ? 'Permitted' : 'permitted'
    " (#{permword}: #{permitted_s})"
  end

  ## Provide a way to register symbol aliases to the Parser
  def self.register_alias(*alias_keys)
    alias_keys.each do |alias_key|
      # pass in the alias-key and the class
      Parser.register(alias_key, self)
    end
  end

  ## Factory class methods ...

  # Determines which type of object to create based on arguments passed
  # to +Optimist::opt+.  This is trickier in Optimist, than other cmdline
  # parsers (e.g. Slop) because we allow the +default:+ to be able to
  # set the option's type.
  def self.create(name, desc="", opts={}, settings={})

    opttype = Optimist::Parser.registry_getopttype(opts[:type])
    opttype_from_default = get_klass_from_default(opts, opttype)

    raise ArgumentError, ":type specification and default type don't match (default type is #{opttype_from_default.class})" if opttype && opttype_from_default && (opttype.class != opttype_from_default.class)

    opt_inst = (opttype || opttype_from_default || Optimist::BooleanOption.new)

    ## fill in :long
    opt_inst.long = handle_long_opt(opts[:long], name)

    ## fill in :short
    opt_inst.short = handle_short_opt(opts[:short])

    ## fill in :multi
    multi_given = opts[:multi] || false
    opt_inst.multi_given = multi_given

    ## fill in :default for flags
    defvalue = opts[:default] || opt_inst.default

    ## fill in permitted values
    permitted = opts[:permitted] || nil

    ## autobox :default for :multi (multi-occurrence) arguments
    defvalue = [defvalue] if defvalue && multi_given && !defvalue.kind_of?(Array)
    opt_inst.permitted = permitted
    opt_inst.default = defvalue
    opt_inst.name = name
    opt_inst.opts = opts
    opt_inst
  end

  private

  def self.get_type_from_disdef(optdef, opttype, disambiguated_default)
    if disambiguated_default.is_a? Array
      return(optdef.first.class.name.downcase + "s") if !optdef.empty?
      if opttype
        raise ArgumentError, "multiple argument type must be plural" unless opttype.multi_arg?
        return nil
      else
        raise ArgumentError, "multiple argument type cannot be deduced from an empty array"
      end
    end
    return disambiguated_default.class.name.downcase
  end

  def self.get_klass_from_default(opts, opttype)
    ## for options with :multi => true, an array default doesn't imply
    ## a multi-valued argument. for that you have to specify a :type
    ## as well. (this is how we disambiguate an ambiguous situation;
    ## see the docs for Parser#opt for details.)

    disambiguated_default = if opts[:multi] && opts[:default].is_a?(Array) && opttype.nil?
                              opts[:default].first
                            else
                              opts[:default]
                            end

    return nil if disambiguated_default.nil?
    type_from_default = get_type_from_disdef(opts[:default], opttype, disambiguated_default)
    return Optimist::Parser.registry_getopttype(type_from_default)
  end

  def self.handle_long_opt(lopt, name)
    lopt = lopt ? lopt.to_s : name.to_s.gsub("_", "-")
    lopt = case lopt
          when /^--([^-].*)$/ then $1
          when /^[^-]/        then lopt
          else                     raise ArgumentError, "invalid long option name #{lopt.inspect}"
          end
  end

  def self.handle_short_opt(sopt)
    sopt = sopt.to_s if sopt && sopt != :none
    sopt = case sopt
          when /^-(.)$/          then $1
          when nil, :none, /^.$/ then sopt
          else                   raise ArgumentError, "invalid short option name '#{sopt.inspect}'"
          end

    if sopt
      raise ArgumentError, "a short option name can't be a number or a dash" if sopt =~ ::Optimist::Parser::INVALID_SHORT_ARG_REGEX
    end
    return sopt
  end

end

# Flag option.  Has no arguments. Can be negated with "no-".
class BooleanOption < Option
  register_alias :flag, :bool, :boolean, :trueclass, :falseclass
  def initialize
    super()
    @default = false
  end
  def flag? ; true ; end
  def parse(_paramlist, neg_given)
    return _paramlist[0] if @multi_given
    return(self.name.to_s =~ /^no_/ ? neg_given : !neg_given)
  end
end

# Floating point number option class.
class FloatOption < Option
  register_alias :float, :double
  def type_format ; "=<f>" ; end
  def parse(paramlist, _neg_given)
    paramlist.map do |pg|
      pg.map do |param|
        raise CommandlineError, "option '#{self.name}' needs a floating-point number" unless param.is_a?(Numeric) || param =~ FLOAT_RE
        param.to_f
      end
    end
  end
end

# Integer number option class.
class IntegerOption < Option
  register_alias :int, :integer, :fixnum
  def type_format ; "=<i>" ; end
  def parse(paramlist, _neg_given)
    paramlist.map do |pg|
      pg.map do |param|
        raise CommandlineError, "option '#{self.name}' needs an integer" unless param.is_a?(Numeric) || param =~ /^-?[\d_]+$/
        param.to_i
      end
    end
  end
end

# Option class for handling IO objects and URLs.
# Note that this will return the file-handle, not the file-name
# in the case of file-paths given to it.
class IOOption < Option
  register_alias :io
  def type_format ; "=<filename/uri>" ; end
  def parse(paramlist, _neg_given)
    paramlist.map do |pg|
      pg.map do |param|
        if param =~ /^(stdin|-)$/i
          $stdin
        else
          require 'open-uri'
          begin
            open param
          rescue SystemCallError => e
            raise CommandlineError, "file or url for option '#{self.name}' cannot be opened: #{e.message}"
          end
        end
      end
    end
  end
end

# Option class for handling Strings.
class StringOption < Option
  register_alias :string
  def type_format ; "=<s>" ; end
  def parse(paramlist, _neg_given)
    paramlist.map { |pg| pg.map(&:to_s) }
  end
end

# Option for dates.  Uses Chronic if it exists.
class DateOption < Option
  register_alias :date
  def type_format ; "=<date>" ; end
  def parse(paramlist, _neg_given)
    paramlist.map do |pg|
      pg.map do |param|
        next param if param.is_a?(Date)
        begin
          begin
            require 'chronic'
            time = Chronic.parse(param)
          rescue LoadError
            # chronic is not available
          end
          time ? Date.new(time.year, time.month, time.day) : Date.parse(param)
        rescue ArgumentError
          raise CommandlineError, "option '#{self.name}' needs a date"
        end
      end
    end
  end
end

### MULTI_OPT_TYPES :
## The set of values that indicate a multiple-parameter option (i.e., that
## takes multiple space-separated values on the commandline) when passed as
## the +:type+ parameter of #opt.

# Option class for handling multiple Integers
class IntegerArrayOption < IntegerOption
  register_alias :fixnums, :ints, :integers
  def type_format ; "=<i+>" ; end
  def multi_arg? ; true ; end
end

# Option class for handling multiple Floats
class FloatArrayOption < FloatOption
  register_alias :doubles, :floats
  def type_format ; "=<f+>" ; end
  def multi_arg? ; true ; end
end

# Option class for handling multiple Strings
class StringArrayOption < StringOption
  register_alias :strings
  def type_format ; "=<s+>" ; end
  def multi_arg? ; true ; end
end

# Option class for handling multiple dates
class DateArrayOption < DateOption
  register_alias :dates
  def type_format ; "=<date+>" ; end
  def multi_arg? ; true ; end
end

# Option class for handling Files/URLs via 'open'
class IOArrayOption < IOOption
  register_alias :ios
  def type_format ; "=<filename/uri+>" ; end
  def multi_arg? ; true ; end
end

## The easy, syntactic-sugary entry method into Optimist. Creates a Parser,
## passes the block to it, then parses +args+ with it, handling any errors or
## requests for help or version information appropriately (and then exiting).
## Modifies +args+ in place. Returns a hash of option values.
##
## The block passed in should contain zero or more calls to +opt+
## (Parser#opt), zero or more calls to +text+ (Parser#text), and
## probably a call to +version+ (Parser#version).
##
## The returned block contains a value for every option specified with
## +opt+.  The value will be the value given on the commandline, or the
## default value if the option was not specified on the commandline. For
## every option specified on the commandline, a key "<option
## name>_given" will also be set in the hash.
##
## Example:
##
##   require 'optimist'
##   opts = Optimist::options do
##     opt :monkey, "Use monkey mode"                    # a flag --monkey, defaulting to false
##     opt :name, "Monkey name", :type => :string        # a string --name <s>, defaulting to nil
##     opt :num_limbs, "Number of limbs", :default => 4  # an integer --num-limbs <i>, defaulting to 4
##   end
##
##   ## if called with no arguments
##   p opts # => {:monkey=>false, :name=>nil, :num_limbs=>4, :help=>false}
##
##   ## if called with --monkey
##   p opts # => {:monkey=>true, :name=>nil, :num_limbs=>4, :help=>false, :monkey_given=>true}
##
## See more examples at http://optimist.rubyforge.org.
def options(args = ARGV, *a, &b)
  @last_parser = Parser.new(*a, &b)
  with_standard_exception_handling(@last_parser) { @last_parser.parse args }
end

## If Optimist::options doesn't do quite what you want, you can create a Parser
## object and call Parser#parse on it. That method will throw CommandlineError,
## HelpNeeded and VersionNeeded exceptions when necessary; if you want to
## have these handled for you in the standard manner (e.g. show the help
## and then exit upon an HelpNeeded exception), call your code from within
## a block passed to this method.
##
## Note that this method will call System#exit after handling an exception!
##
## Usage example:
##
##   require 'optimist'
##   p = Optimist::Parser.new do
##     opt :monkey, "Use monkey mode"                     # a flag --monkey, defaulting to false
##     opt :goat, "Use goat mode", :default => true       # a flag --goat, defaulting to true
##   end
##
##   opts = Optimist::with_standard_exception_handling p do
##     o = p.parse ARGV
##     raise Optimist::HelpNeeded if ARGV.empty? # show help screen
##     o
##   end
##
## Requires passing in the parser object.

def with_standard_exception_handling(parser)
  yield
rescue CommandlineError => e
  parser.die(e.message, nil, e.error_code)
rescue HelpNeeded
  parser.educate
  exit
rescue VersionNeeded
  puts parser.version
  exit
end

## Informs the user that their usage of 'arg' was wrong, as detailed by
## 'msg', and dies. Example:
##
##   options do
##     opt :volume, :default => 0.0
##   end
##
##   die :volume, "too loud" if opts[:volume] > 10.0
##   die :volume, "too soft" if opts[:volume] < 0.1
##
## In the one-argument case, simply print that message, a notice
## about -h, and die. Example:
##
##   options do
##     opt :whatever # ...
##   end
##
##   Optimist::die "need at least one filename" if ARGV.empty?
##
## An exit code can be provide if needed
##
##   Optimist::die "need at least one filename", -2 if ARGV.empty?
def die(arg, msg = nil, error_code = nil)
  if @last_parser
    @last_parser.die arg, msg, error_code
  else
    raise ArgumentError, "Optimist::die can only be called after Optimist::options"
  end
end

## Displays the help message and dies. Example:
##
##   options do
##     opt :volume, :default => 0.0
##     banner <<-EOS
##   Usage:
##          #$0 [options] <name>
##   where [options] are:
##   EOS
##   end
##
##   Optimist::educate if ARGV.empty?
def educate
  if @last_parser
    @last_parser.educate
    exit
  else
    raise ArgumentError, "Optimist::educate can only be called after Optimist::options"
  end
end

module_function :options, :die, :educate, :with_standard_exception_handling
end # module

###############
# CLI Options & Parsing
###############

OPTS = Optimist::options do
  version VERSION
  banner <<~EOF
    #{PRGNAME}  version #{VERSION}
    Copyright (C) #{COPYRIGHT} by #{AUTHOR}
    Compatibility: MacOS and Linux
    License: #{LICENSE}

    #{PRGNAME} is a tool to backup and sycnhronize multiple folders,
    drives, or other storage locations based on the configuration set
    in a YAML config file. If the file location is not passed in
    explicitly #{PRGNAME} will search for it in this order:

        ./#{PRGNAME}.yaml
        ~/.#{PRGNAME}.yaml
        /etc/#{PRGNAME}.yaml

    Usage: #{File.basename(__FILE__)} [OPTIONS]

    Options:
  EOF
  opt :"dry-run", "Simulates a run without performing any changes"
  opt :edit, "Edit the backupchain config", short: :none
  opt :fsck, "Runs an fsck check on disks flaggd in the config before any backup is made on/from them", default: true, short: :none
  opt :"fsck-only", "Specify which locations to run fsck on. Ignored if --fsck is also provided", type: :string, short: :none, multi: true
  opt :init, "Creates a skeleton config file in the current working directory"
  opt :verbose, "Enables verbose output. Twice will enable very-verbose output (good for logging)", multi: true
  opt :version, "Print version and exit", short: :none
  opt :yaml, "Specify a yaml file to load", type: :string, short: :none
  opt :yes, "Assume 'yes' to all questions for headless execution"
end

## Set Up Logger
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
      'FATAL' => {background: :red},
      'ANY' => :default
    }

    @logger.formatter = proc do |severity, time, progname, msg|
      #original_formatter.call(severity, time, progname, msg.dump)
      msg.lines.map{|m|
        if fmt == :standard
          "[#{time.strftime("%Y-%m-%d %H:%M:%S.%6N")}] #{progname} || #{severity + (' ' * (5 - severity.length))} || #{m.strip_color}"  # Strips color from the message
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


if OPTS[:verbose] >= 2
  Log::make_logger level: -1, fmt: :standard
elsif OPTS[:verbose] == 1
  Log::make_logger level: :debug, fmt: :simple
else
  Log::make_logger level: :info, fmt: :display
end

System.log.debug "Parsed CLI Options: #{OPTS}"

###############
# Non-Backup Commands
###############
# Init
if OPTS[:init]
  cfgfile = "#{PRGNAME}.yaml"
  if File.exist?(cfgfile)
    System.log.error "The file #{cfgfile} already exists in the current directory. Please rename or delete it before running init."
    exit 1
  end
  File.write(cfgfile, Config.skeleton)
  System.log.info "Initialized config file ./#{cfgfile}"
  exit
end

# Edit
if OPTS[:edit]
  config_locs = OPTS[:yaml_given] ? [OPTS[:yaml]] : %W(./#{PRGNAME}.yaml ~/.#{PRGNAME}.yaml /etc/#{PRGNAME}.yaml )
  config_locs.map{|c| File.expand_path(c)}.each do |conf|
    if File.exist?(conf)
      system("vi #{conf}")
      break
    end
  end
  exit 0
end

###############
# Load Config
###############
default_config_locs = %W(./#{PRGNAME}.yaml ~/.#{PRGNAME}.yaml /etc/#{PRGNAME}.yaml )
config = Config.new (OPTS[:yaml_given] ? [OPTS[:yaml]] : default_config_locs)
if !config.empty?
  System.log.info "Loaded config file from " + (OPTS[:yaml_given] ? "'#{OPTS[:yaml]}'" : "default locations")
else
  System.log.error "Config file could not be located. Please create a valid config file at one of the following locations or specify one by using '--yaml=' :  " + default_config_locs.join(' ,  ')
  exit 1
end

###############
# Verify Everything
###############
if !config.validate!
  System.log.error "The provided config is invalid. Please fix the following errors before continuing."
  config.validation_errors.each{|err| System.log.error err}
  exit 1
else
  System.log.debug "The config file was successfully validated against the schema"
end

unfounds = OPTS[:"fsck-only"].reject{|fsck_loc| config[:locations].map{|name, location_config| name}.include?(fsck_loc)}
if unfounds.length > 0 then System.log.fatal "Locations specified for fsck but are not defined in the config: #{unfounds.join(' ')}. Exiting to prevent unexpected behavior."; exit 1 end
unfounds = OPTS[:"fsck-only"].reject{|fsck_loc| config[:locations][fsck_loc].keys.include?(:disk) && config[:locations][fsck_loc][:disk][:can_fsck]}
if unfounds.length > 0 then System.log.fatal "Locations specified for fsck but do not have fsck enabled in the config: #{unfounds.join(' ')}. Exiting to prevent unexpected behavior."; exit 1 end

###############
# Backup Process
###############
if `which cowsay` != "" then System.log.info `cowsay -f stegosaurus 'Time for a backup!'`.lines.each_with_index.map{|line, index| if index <= 2 then line.colorize(:red) elsif index <= 6 then (line[0..4].colorize(:red) + line[5..-1].colorize(:cyan))  else line.colorize(:cyan) end}.join.colorize(mode: :bold)
else System.log.info "eJyNlM1qwzAMgO95hVzUXrZDbbdsFEZLX2GX3hLqdGODUcJKobdUzz7JP/lx\n7CyyiS3L+ixZJnmx2b1sdq9vNeiIQJYX6zpvN+3h+FN/wffvDc7wcf683K8L\nOASbQEQkJJVA0i5tjV9KpB/Dg8rZDAUVU+QTLMNIgDHTFEkJkPue5wc/2NUR\njGjTsAbMJuoCkJqg4LiTJUt42lp04UiBAyQKXkp4N+23RMSSriAilVRkVHFE\nV0RiaK1Sl8y2KIHPfHdpg0u2J14na786HeDZXMDKBqpHGTTt7EGQdCKVsHUM\nz30MKWoyF4+Sw7NVVKVHt0JM1tUJlU9r56m0eRYnrwrQHiUFJ/4PqxeFiqno\nAucEiMx9FtFUoEmo5hUzzzX7R/gDbknaPA==\n".decompress
end

# Parse Locations
locations = config[:locations].map do |name, location_config|
  [name.to_sym, Location.create(**location_config.merge!({name: name.to_s}))]
end.to_h

# Parse Execution Tree
trees = config[:execution_tree].map do |root_node|
  ExecutionNode.new(root_node, locations, config[:rsync_defaults])
end

# Check Availability
System.log.info 'Analyzing Backup Targets'.colorize(color: :cyan, mode: :bold)
locations.each do |name, loc|
  loc.analyze!
end

# Show Backup Plan
System.log.info 'Confirm Backup Plan'.colorize(color: :cyan, mode: :bold)
trees.each_with_index do |root, index|
  root.show_full_tree show_legend: (index == 0)
end

# Confirm Plan unless -f option is passed
unless OPTS[:yes]
  userkey = ''
  printf "\nConfirm? (y/n): "
  userkey = STDIN.getch until ['y','n'].include? userkey.downcase
  exit if userkey == 'n'
end

# Run Backup
System.log.info 'Running Backups'.colorize(color: :cyan, mode: :bold)

# Nodes in execution goups
trees.chunk{|root| root.execution_group}.each do |chunk, roots|
  System.log.info "Execution group #{chunk} running.".colorize(mode: :bold)
  roots.map{|root| Thread.new{ root.backup(dryrun: OPTS[:"dry-run"], fsck_hosts: OPTS[:fsck] ? locations.keys.map{|k| k.to_s} : OPTS[:"fsck-only"]) }}.each(&:join)
end

# Nodes not in execution groups
sequential = trees.select{|root| root.execution_group.nil?}
System.log.info "Sequential backups running".colorize(mode: :bold) if sequential.count > 0
sequential.each do |root|
  root.backup(dryrun: OPTS[:"dry-run"], fsck_hosts: OPTS[:fsck] ? locations.keys.map{|k| k.to_s.downcase} : OPTS[:"fsck-only"].map{|h| h.downcase})
end

# Done
System.log.info 'Done'.colorize(color: :cyan, mode: :bold)