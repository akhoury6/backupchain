#!/usr/bin/env ruby

action, file = ARGV
actions = ['c', 'compress', 'd', 'decompress']
if !actions.include?(action) || file.nil? || !File.exist?(file)
  puts "Specified action invalid. Please use one of: #{actions.join('  ')}" if !actions.include?(action)
  puts "Invalid file. Please check path and try again." if file.nil? || !File.exist?(file)
  puts "Usage: #{File.basename(__FILE__)} <action> <file>"
  exit
end

%w(zlib base64).each { |lib| require lib }
String.instance_eval { define_method(:c) { Base64.encode64(Zlib::Deflate.deflate(self)) } }
String.instance_eval { define_method(:d) { Zlib::Inflate.inflate(Base64.decode64(self)) } }
puts File.read(File.expand_path(file)).send(action[0].downcase.to_sym).dump
