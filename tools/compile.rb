#!/usr/bin/env ruby
## This tool compiles the entire backup program into a portable script

%w(zlib base64).each{ |lib| require lib }
String.instance_eval{define_method(:compress){Base64.encode64(Zlib::Deflate.deflate(self))}}
String.instance_eval{define_method(:decompress){Zlib::Inflate.inflate(Base64.decode64(self))}}

MAINDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
LIBDIR = File.expand_path(File.join(MAINDIR, 'lib'))

$files = {
  'SKELFILE' => File.read(File.expand_path(File.join(MAINDIR, 'lib', 'example.yaml'))).compress.dump,
  'SCHEMAFILE' => File.read(File.expand_path(File.join(MAINDIR, 'lib', 'backupchain.schema.yaml'))).compress.dump
}

def flatten_rubyfile filename
  parsed_file = Array.new
  basedir = File.dirname(filename)
  lines = File.readlines(filename)
  lines.map{|line| line.chomp}.each do |line|
    if line.start_with? 'require_relative'
      _, reqpath = line.split(' ', 2)
      reqpath = eval(reqpath)
      reqpath.sub!(basedir, '')
      reqpath = '/' + reqpath unless reqpath.start_with?('/')
      reqpath = File.join(basedir, reqpath)
      parsed_file.push flatten_rubyfile(reqpath)
      puts "IMPORTED #{File.basename reqpath}"
    elsif m = line.match(/##REPLACE#([^#]+)##/)
      parsed_file.push line.sub(/\"[^\"]+\"/, $files[m[1]])
      puts "REPLACED #{m[1]}"
    else
      parsed_file.push line
      next
    end
  end
  parsed_file
end


flat_script = flatten_rubyfile(File.join(MAINDIR, 'backupchain.rb')).join("\n")
File.write File.join(MAINDIR, 'portable', 'backupchain-portable.rb'), flat_script

puts "DONE"