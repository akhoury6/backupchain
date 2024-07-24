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
    entries.select{|e| e["Host"].include?(host) || (also_search_hostname && e["Hostname"] == host)}.first || {}
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