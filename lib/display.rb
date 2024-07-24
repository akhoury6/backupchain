###############
# Display Controller Class
###############
class Display
  def initialize output_as_logs: false, verbose: false, suppress_color: false
    binding.local_variables.each { |var| self.instance_variable_set("@#{var}", binding.local_variable_get(var.to_sym)) }
  end

  def banner
    if @output_as_logs
      out "Beginning Backup"
    else
      out "eJxTUFBQiMcGuIASCjYKQaV5eZl56QpOicnZpQWKIKBgB5bTxQbAMlAQA8Rx\n8fFxyGIgQY38fM0YZFuQgEZ8vGYMlK2pH4MuDQI1NSCLyhVqsEtCKS4A5lss\nxw==\n".decompress.colorize(:cyan)
    end
  end

  def divider text = nil
    if @output_as_logs
      out text
      return
    end
    divider_color = { color: :cyan, background: :default }
    if text.nil?
      text = "————————————————————————".colorize(divider_color)
    else
      text = "        ".colorize(divider_color).underline + ' ' + text + ' ' + "        ".colorize(divider_color).underline
    end
    out "\n#{text}\n\n"
  end

  def out text = '', verbose: false, indent: 0
    return if verbose && !@verbose
    text.gsub!(/\e\[([;\d]+)?m/, '') if @suppress_color || @output_as_logs
    if @output_as_logs
      text.each_line { |line| puts Time.now.to_s + '  ' + (' ' * indent) + line }
    else
      text.each_line { |line| puts (' ' * indent) + line }
    end
  end
end
