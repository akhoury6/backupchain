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
        device_info = run_command!("diskutil info #{device_path_df}", capture_output: true, silent: true).lines.map { |l| l.chomp }.reject(&:empty?).map { |l| l.split(':').map { |h| h.strip } }.reject { |arr| arr.length != 2 }.to_h
        @_root_available = device_info.keys.include?('Volume UUID') && device_info['Volume UUID'] == @disk[:uuid].upcase
      end
    end
    @_root_available
  end

  private def root_status_message
    return @root.colorize(@highlight_color) + ' is in an ' + 'unknown'.colorize(:gray) + ' state.' unless defined?(@_root_available)
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
      blkid_info = ("DEVICE=" + blkid_info.sub(':', '')).gsub('"', '').split(' ').map { |e| e.split('=') }.to_h
      # Mount the disk
      run_command!('sudo mount "' + blkid_info['DEVICE'] + '" --target "' + @root + '"')
    elsif operating_system == :darwin
      # First ensure the device is connected and get its details
      all_disk_info = run_command!("diskutil info -all", capture_output: true, silent: true)
      all_disk_info = all_disk_info.split('**********').map { |drive| drive.lines.map { |l| l.strip }.reject(&:empty?).map { |l| l.split(':').map { |h| h.strip } }.reject { |arr| arr.length != 2 }.to_h }.reject(&:empty?)
      return false if ! diskinfo = all_disk_info.select { |disk| disk.keys.include?('Volume UUID') && disk['Volume UUID'] == @disk[:uuid].upcase }[0]
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
      device_info = run_command!("diskutil info #{part}", capture_output: true, silent: true).lines.map { |l| l.chomp }.reject(&:empty?).map { |l| l.split(':').map { |h| h.strip } }.reject { |arr| arr.length != 2 }.to_h
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
    unless defined?(@_fsck_status)
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
    else
      System.log.fatal "Unknown fsck error encountered. Halting execution."
      @_root_available = false
      @_available = false
      exit 1
    end
  end
end