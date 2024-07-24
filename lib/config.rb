###############
# Config Storage Class
###############
class Config < Hash
  def self.skeleton
    skelfile = File.join(File.dirname(__FILE__), 'example.yaml')
    begin
      File.read(skelfile)
    rescue Errno::ENOENT
      System.debug "Could not load skeleton config at the following location. Failing over to the hardcoded base64 skeleton: '#{skelfile}'"
      "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\n4dzzpMT51v1fv/A4Dg==\n".decompress ##REPLACE#SKELFILE##
    end
  end

  def initialize locations_arr = []
    @location = nil
    @validation_msg = nil
    config = nil
    locations_arr.map { |filepath| File.expand_path(filepath) }.each do |filepath|
      begin
        config = YAML.safe_load_file(filepath, symbolize_names: true, aliases: true)
        System.log.debug "Loaded valid YAML config file at '#{filepath}'"
        @location = filepath
        break
      rescue Errno::ENOENT
        System.log.debug "Attempted to load YAML config file but did not find it at: '#{filepath}'"
      rescue Psych::SyntaxError => e
        System.log.warn "Invalid YAML syntax found at '#{filepath}'"
        System.log.warn e.message
      end
    end
    config.keys.each { |k| self[k] = config[k] } unless config.nil?
    super
  end

  def validate!
    schemafile = File.join(File.dirname(__FILE__), 'backupchain.schema.yaml')
    schema = nil
    begin
      schema = YAML.safe_load_file(schemafile)
      System.log.debug "Loaded config schema file from '#{schemafile}'"
    rescue Errno::ENOENT
      System.debug "Could not load schemafile at the following location. Failing over to the hardcoded base64 schema: '#{schemafile}'"
      schema = YAML.safe_load "eJzVV0tv3DYQvu+vINQ92K5kOW7tgy5Fk14KGGgOOdWwF1xpJDGmSJUcxdmg\nP76kHqvHUtq1myAtgcVSnOHMNw8OOUEQrLw1S7yI5IiljsKQPuWyUrvbcEvj\npzinTFzqOIeCXn7UUqzCkHjrZmGwyZKClk2qLEwUTTG8vrq+Ct5chw1hhQw5\nRORtJ5e8kyJlWaUoMiMZd6Whyu1HiHGl4K+KKUgick+4jGsO7RP4DHFl5xtU\nAORhRZOE2W/K3ytZgkIGOiIp5RpWZb+yIkTpnYg3CaS04livEGOJgtSY4f0Q\nrg1FhzWTLFF7hr7X2zAnoGPFSrsSkTumkciUWCdVJUGqMkBNUBIN3BhAUiUL\nQkVCMAemzCoiE5muJY0stQslRQQl3o8A1wAvL7xu3iOwAN42ij/UisldC5X8\nBikTtUf2uw602TH0r5ISjSs70pJLO57yAGkt1Agafne6NSpj+4jQWhyRx7Oz\nX6L7x/DhIjy/OD+7vDhfDxgTpp/GEqWAP9LxEiFBq2grJQcqZqgTFyxKbPYN\nvUQrlIWsBPqkqlgycNhwnOK8kR+cjhxJ7PTOMZBF4/sRm0zGiKCq3FBIbdcx\nLY5YDkcqVUGNFitqhimmYpPq+On19gTfx82zidLjOi0SdrTRmIc8FnnE7UOJ\nGun2fxrgnGU5Nz/cxJJLdWItAVEV9oRuuamJvjm0iU8ycz0In+yAc/nsG1IF\nPiloBgKpT+IdNcTnnKFZba8EnzSaWynNRy2rmbYSm49ObrfFSm/mex2tHbWm\nZt7qyxTd1QB3oxqide6y11G0Tk1+KnauUjm9WvlBKRvzKCgkwoRp/kDFZpvx\nADNwDhNgsRC/5FA7bTvEXmlQzko9ZnuCXcr41MZlO+2w4t1ZfuQstQpftffk\ny3PhXdEN7/GsToG/myCfr70Xxmx0QyaJy9kvCeuyu62CV7qsLVszFelIZQ8I\nKz/9vEy+XSDnUqOgxXydNxISESywlVLNgG8sZwIhA+XkKMyDsLAV8spNpp8b\n8u3NzU83qxFhg7kCmuivXJjmo2y1zWXgnI17+95MSM/K1Nt/JW3cbjjagA85\n2Hu372JsT5DLZ9sIND3OQYNg/vJWb4OEKnMh1N8GbtE//ae9SQ9GyAQ807fZ\nZW/f29i2ZQbiu7vfiay/6xalpLr+r7cdR+I4XPsK5D3e/xr8SYMvwcOP3shj\nFmTkbneO5clhfnStWB9NB6hed6ZkVU55pxF3nIv9Wbi+6U4CM441nNlU2iT9\nX980adNtx7BJJU9AbeQnUIolk7RdbHoOqp4JP7byvm431rTQbSJtCjApPVYw\n8+JYbrNdNomK81nFbh99C92ywkx+y+DblN0UcmrL0aduajBaO3yic5ainY4f\nk8OkOkl2SRXlHDj74sRy+Fb/bsnQllIXyr6AdWNUyBaRHe21HNCnJblnTinj\nNk//kzD/Adc2Fvs=\n".decompress ##REPLACE#SCHEMAFILE##
    end
    begin
      JSON::Validator.validate!(schema, self)
    rescue JSON::Schema::ValidationError => e
      @validation_msg = JSON::Validator.fully_validate(schema, self)
      return false
    end
    return true
  end

  def validation_errors
    return @validation_msg
  end
end
