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