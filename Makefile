all: caches portable

caches:
	./tools/update_cached_yaml.rb

portable: backupchain-portable.rb
	./tools/compile.rb
