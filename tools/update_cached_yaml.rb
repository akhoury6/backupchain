#!/usr/bin/env ruby
## This tool updates the cahced base64 strings in the code files

%w(zlib base64).each{ |lib| require lib }
String.instance_eval{define_method(:compress){Base64.encode64(Zlib::Deflate.deflate(self))}}
String.instance_eval{define_method(:decompress){Zlib::Inflate.inflate(Base64.decode64(self))}}

MAINDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
LIBDIR = File.expand_path(File.join(MAINDIR, 'lib'))

$files = {
  'SKELFILE' => File.read(File.expand_path(File.join(MAINDIR, 'lib', 'example.yaml'))),
  'SCHEMAFILE' => File.read(File.expand_path(File.join(MAINDIR, 'lib', 'backupchain.schema.yaml')))
}

Dir.glob("#{MAINDIR}/**/*.rb").each{ |filename|
  lines = File.readlines(filename)
  changes = false
  parsed_lines = []
  lines.each{ |line|
    if m = line.match(/##REPLACE#([^#]+)##/)
      parsed_lines.push line.sub(/\"[^\"]+\"/, $files[m[1]].compress.dump)
      changes = true
      puts "REPLACED #{m[1]}"
    else
      parsed_lines.push line
    end
  }
  if changes
    puts filename
    File.write(filename, parsed_lines.join)
  end
}

readmefile = File.join(MAINDIR, 'README.md')
readmetext = File.read(readmefile)
matches = readmetext.match /(.*)(<!-- BEGIN SKELFILE -->)(.*)(<!-- END SKELFILE -->)(.*)/m
matches = matches.to_a
matches[3] = "\n\`\`\`yaml\n" + $files['SKELFILE'] + "\n\`\`\`\n"
puts "REPLACED SKELFILE"
puts readmefile
File.write(readmefile, matches[1..-1].join)

puts "DONE"