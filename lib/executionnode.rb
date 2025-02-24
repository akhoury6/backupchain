###############
# Execution Tree Class
###############
class ExecutionNode
  def initialize node, locations, rsync_defaults
    node = { location: node } if node.is_a?(String)
    @host = locations[node[:location].to_sym]
    @execution_group = node[:execution_group] || nil
    @incoming = {
      source_folder_override: nil, dest_folder: '/', parallelize: false, rsync_options_merge: [], rsync_options_override: []
    }.merge((node[:incoming] || {}).compact)
    @outgoing = {
      source_folder: '/', exec_mode: nil, parallelize: false, rsync_options_merge: [], targets: [], failovers: []
    }.merge((node[:outgoing] || {}).compact)
    @outgoing[:targets].map! { |target| ExecutionNode.new(target, locations, rsync_defaults) }
    @outgoing[:failovers].map! { |target| ExecutionNode.new(target, locations, rsync_defaults) }
    @rsync_defaults = rsync_defaults || []
  end

  attr_reader :host, :execution_group, :incoming

  def backup exec_mode: 'fullsync', fsck_hosts: [], dryrun: false
    planned_targets = @outgoing[:targets].select { |target| target.host.available? }
    planned_failovers = @outgoing[:failovers].select { |target| target.host.available? }
    return false if !@host.available? || planned_targets.empty? && planned_failovers.empty?
    exec_mode = @outgoing[:exec_mode] || exec_mode
    backed_up_to_a_target = false

    perform_fsck = Proc.new { |node, highlight: false|
      System.log.debug "Host #{node.host.name.colorize(node.host.highlight_color)} #{node.host.available? && node.host.can_fsck? ? 'is' : 'is not'} configured for an fsck check.".colorize(highlight && node.host.highlight_color)
      if node.host.available? && node.host.can_fsck?
        if dryrun
          System.log.info "Dry-run mode enabled. Skipping fsck check for #{node.host.name.colorize(node.host.highlight_color)}."; next
        end
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

    System.log.info "Began backup process for #{@host.name.colorize(@host.highlight_color)} with planned targets #{planned_targets.map { |n| n.host.name.colorize(n.host.highlight_color) }.join(', ')}#{planned_failovers.empty? ? '' : ' and failovers ' + planned_failovers.map { |n| n.host.name.colorize(n.host.highlight_color) }.join(', ')}".colorize(mode: :bold)
    self.host.add_reader
    perform_fsck.call(self, highlight: @outgoing[:parallelize]) if fsck_hosts.include?(@host.name.downcase)
    if @outgoing[:parallelize]
      planned_targets.select { |target| target.host.available?(force_check: true) }.map { |target| Thread.new { perform_backup.call(target, highlight: true) } }.each(&:join)
    else
      planned_targets.select { |target| target.host.available?(force_check: true) }.each { |target| perform_backup.call(target, highlight: true) }
    end
    if !backed_up_to_a_target && planned_failovers.count > 0
      System.log.warn "No primary targets have been backed up to for host #{@host.name}. Using available failovers."
      System.log.warn "As a precaution parallel execution will be disabled for these operations." if @outgoing[:parallelize]
      planned_failovers.select { |target| target.host.available?(force_check: true) }.each(&perform_backup)
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
    to = "/#{@incoming[:dest_folder].sub(/^\//, '')}".colorize(hostcol)

    parts = Array.new
    parts.push from.nil? ? indents.join : indents[0..-2].join
    parts.push from.nil? ? '' : "#{branch_char}#{graphchar} #{from} #{graphchar}#{graphchar} #{to} #{graphchar} "
    parts.push from.nil? ? @execution_group.nil? ? '   ' : (' ' * (3 - @execution_group.digits.count)) + @execution_group.to_s + ' ' : ''
    parts.push @host.name.colorize(hostcol)
    parts.push '*'.colorize(unavailable ? :gray : nil) if parallelize
    next_line_indent = ' ' * (parts.join.strip_color.length - (@host.name.length / 2)) #(@host.name.length / 2 + (from.nil? ? 0 : from.strip_color.length + to.strip_color.length + 9 ))
    # parts[4] = @outgoing[:targets].empty? ? '' : "\n" + indents.join + next_line_indent + "/#{@incoming[:dest_folder].sub(/^\//,'')}".colorize(hostcol)
    System.log.info parts.join

    targets_available = @outgoing[:targets].map { |t| t.host.available? }.reduce { |result, available| result || available }
    all = @outgoing[:targets] + @outgoing[:failovers]
    all.each_with_index do |t, i|
      t.show_full_tree(
        from: ('/' + (t.incoming[:source_folder_override] || @outgoing[:source_folder]).sub(/^\//, '')).colorize(@host.highlight_color),
        parent: self,
        indents: indents + [next_line_indent,
                            t != all[-1] ? chars[:v].colorize(
                              if @outgoing[:failovers].include?(all[i + 1])
                                unavailable || targets_available ? :gray : :red
                              else
                                unavailable || !targets_available ? :gray : :blue
                              end
                            ) : ' '],
        failover: @outgoing[:failovers].include?(t),
        branch_char: (
          (t == @outgoing[:targets][-1] && @outgoing[:failovers].empty?) ||
            (t == @outgoing[:failovers][-1]) ? chars[:l] : chars[:m]
        ).colorize(
          if @outgoing[:failovers].include?(t)
            unavailable ? :gray : :red
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
    rsync_options = rsync_options.map { |opt| /^-[^-]+$/.match(opt) ? opt.chars[1..-1] : opt }.flatten.map { |opt| /^--[^-].+$/.match(opt) ? opt[2..-1] : opt }.uniq
    rsync_options = ['dry-run'] + (rsync_options - ['n', 'dry-run']) if dryrun
    System.log.debug "Dry run mode: #{dryrun}. Pre-processed rsync options: #{rsync_options}"
    rsync_options.concat(['.DocumentRevisions-V100', '.Spotlight-V100', '.TemporaryItems', '.Trashes', '.fseventsd', '.DS_Store', 'lost+found'].map { |xcl| "exclude #{xcl}" })
    rsync_options.uniq!
    short_opts = rsync_options.select { |opt| opt.length == 1 }
    rsync_options = rsync_options.reject { |opt| opt.length == 1 }.map { |opt| '--' + opt }
    rsync_options.unshift(short_opts.unshift('-').join) if short_opts.length > 0
    cmd = executable + ' ' + rsync_options.join(' ')

    num_remotes = [@host, target.host].map { |h| h.is_a?(RemoteHost) }.count(true)
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
    if [@host, target.host].map { |h| h.is_a?(RemoteHost) }.count(true) == 0
      msg += 'locally...'
    else
      lan_locs = [@host, target.host].select { |h| h.is_a?(RemoteHost) && h.loc == :local }
      wan_locs = [@host, target.host].select { |h| h.is_a?(RemoteHost) && h.loc == :remote }
      msg += 'over the ' + (wan_locs.length > 0 ? 'internet'.colorize(wan_locs.last.highlight_color) : 'local network'.colorize(lan_locs.last.highlight_color))
      msg += '...'
    end
    msg += " (Parallelized output will be colored)".colorize(color) unless color == :default || color.nil?
    msg
  end
end
