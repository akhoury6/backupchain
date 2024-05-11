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
    locations_arr.map{ |filepath| File.expand_path(filepath) }.each do |filepath|
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
    config.keys.each{|k| self[k] = config[k]} unless config.nil?
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
      schema = YAML.safe_load "eJzVV0tv4zYQvvtXEKoPSSpF2bTJQZeiu70UCNA97KmBY9DSSOKaIlVytFkv\n+uNL6mFZMiU76S62FWCY5AxnvnlwyAmCYOEtWeJFJEcsdRSGdJvLSu3uww2N\nt3FOmbjWcQ4Fvf6opViEIfGWzcLBJksKWjapsjBRNMXw9ub2JnhzGzaEBTLk\nEJG3nVzyToqUZZWiyIxk3JWGKjcfIcaFgr8qpiCJyCOXcc2gfQKfIa7seI0K\nYLWgScLslPL3SpagkIGOSEq5hkXZrywIUXon4nUCKa041ivE2KEgNUZ4P4RL\nQ9FhzSRL1J6h79U2zAnoWLHSrkTkgWkkMiXWRVVJkKoMUBOURAM38EmqZEGo\nSAjmwJRZRWQi07WkgZ12oaSIoMT7AeAa4PWV1417BBbA20bxh1oxeWihkt8g\nZaL2yH7XkTb7HXhXSYmrPWHOoR1PeYSzFmnkHM47zRqVsXxAaO2NyNPFxS/R\n41O4ugovry4vrq8ulweMCdPboUQp4I90uERI0CraSMmBignqyAGzEpt9Bz6i\nFcpCVgJ9UlUsWTn4z3PdwAtONw4kdmqnGMis6f0XmyzGiKCq3FBIbdYpLY5I\nHn6pVAU1WqyoCaaYinWq4+3r7Qm+j5sn06THdV4k7NdGYxryUOQJtx9K1Eg3\n/9MA5yzLufnhOpZcqjMrCYiqMOdzw0059M2JTXySmYtB+GQHnMtnn2x4BT4p\naAYCqU/iHTXE55yhWW1vA580ilspzaSW1Qxbic2kk9ttsdKb8V5Ha0atqRm3\n+jJFdzXA3WEF0Tp3WesoWOemPhU7V5kcXal8XMYGHAoKiTBkmT5KsdlkjGcG\nynHoZwvwS46z064j5JUG5arQA6Yt7FLG4ZhvvlxY2e7cPnGCWn2v2nv2hTnz\nkug+7+mijv3fTXwvl94L43V4KyaJw9EvCei8s638VzqsLVUTVehENQ8IKz/9\nPE++nyHnUqOgxXRtNxISEcywlVJNgG8sZwIhA+XkKMwDsLBV8cZNpp8b8v3d\n3U93iwFhjbkCmuivXI6mo2y1TeXflI17+96MSM/KFNl/JW3YXTie/R9ysHdt\n37PYHiCXz/bh33Q0Rw2B+ctbvQ0SqswtUM8N3KJ/6o97kR6MkAl4pkuzy96+\nl7FtygTEdw+/E1nP65akpLr+r7edRuI4XPv64z09/hr8SYMvwepHb+AxCzJy\ntzen8uQ4P7rWq4+mA1SvO1OyKse844g7zsX+LNzedSeBGccazmwsbZT+r2+T\ntOmtY1inkieg1vITKMWSUdrOtjlHVc+EH1t5X7f/alrmNpHWBZiUHiqYeGfM\nt9Uum0TF+aRit4++hW5ZYSa/ZfBtyq4LObbl1PM2NRCtGT7ROUvRDldTKXWW\n5JIqyjlw9sWJ5Ph1/t1SoS2kLpR9+eq+QRmbRXayu3JAHxfknjmljNss/U/C\n/Acv2hR7\n".decompress ##REPLACE#SCHEMAFILE##
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