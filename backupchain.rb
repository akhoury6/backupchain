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
require_relative File.join(LIBDIR, 'location.rb')
require_relative File.join(LIBDIR, 'executionnode.rb')
require_relative File.join(LIBDIR, 'config.rb')
require_relative File.join(LIBDIR, 'logging.rb')
require_relative File.join(LIBDIR, 'optimist.rb')

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
require_relative File.join(LIBDIR, 'logging.rb')
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
