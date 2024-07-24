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

  def initialize * params
    super **params.to_h
  end
end

class LocalRemovableDisk < LocalHost
  include RemovableDiskModule

  def initialize * params
    super **params.to_h
  end
end
