###############
# Config Storage Class
###############
class Config < Hash
  def self.skeleton
    skelfile = File.join(File.dirname(__FILE__), 'example.yaml')
    begin
      File.read(skelfile)
    rescue Errno::ENOENT
      System.debug "Could not load skeleton config at the following location. Failing over to the hardcoded base64 schema: '#{schemafile}'"
      "eJyVWNFuG7sRffdXEMmDbcCSEjuOE6EokN40uBfIbYrrpECfHO4uV2LNJVWS\nK1t5uN/eM0Nyd6XIBioghrIiOTNnzpwZ7mw2OzGullE7G5biyc9LcfaH+m+v\nvWrOxUfVaqtEXCsx7MX/ZORH0Tkjwtr1phGVrO9Fv8EzIW2zcF603nUnQvzq\nOiU+OdMovzwhA965uBSLNZ4vul0flOfHa71aG/yLd7Uzzi/Fyitl8dNtdF6u\nlPjo9VbtHdHZuAjpV37c6HC/FNH36snQvmwoBmnOxScjV4hCIx7pVyoKGYQU\nXnVuKyujxFr6RjRkU7SIpnNeCVnXvZcRX7ZSG1lpo+NONCqqmo6di1+kFdIE\nYNBH1wGvWhqzE1vldbsbgaud99giNtJr2ii+ffvto4ArnettVI04Czsb5aOo\nlHEP58fx2SmDH/Hb3wA9kL9VHnaOZnYvp/+QSIhrUwY59ENMq3TgM2f8U8Z1\nOSOvpv18UAjrZ+h1kIXf0hm3t7+KCgy7JxAaJl1zMfGQHkevJGEz5Al5CBzz\nSTq4hmvKRo0EHHHgJf0hO7+My+bi364XndyJcK83ZC8oodmlnZBIeHZFaCv+\nXMwR2aJ2ttWrk3Iq0Xcp1KPsNkYNT+/VrtVGLcsm3dz5IPPPVEjmSYReiq9r\niitGbVeBqYe46zX+l9iaQhYgTalKI6yKD87fzwnOysX14IhsGrj3+v3l/PXb\nd/PX89evDgDJB6BkC6STsC8mJhC3TSwXD9oYMFPIGFW3QUoGcxvnwaHLy+OB\n0afVPkQ2R0dnk+VAgJnT26JsiFdz8SEKoyT2OFvwTbueQjDZSdxENgGM6Hrs\nrybZbGGKAAUd5gdYdbv5pq+MrueNDfOaJWw/uInUPP3ZI/lHFfTKsm5kRUGQ\no9IQGmGjapIISZoQkyhASlkPRFaNFXZarrM5SEJqAeKy2gQN+u0oRBCH9p2S\nCJ4KkOcUUAZ8jcOqeq1QZ6xFkuOg4tp4gGVjDpbVi0wvBW8/hvCHPYVLjpKX\no/+AWXPltvixmUOg2Ld0Ir5kVXTW7ObUaWRvIi0uPmdn+l43S/FWtVV7/f5m\n9v7VqzezNzdK4dvby9n1K3VzdVXfXDaXklz7lzM99I0FlWOEffUIdFk6kovs\n7MZpy0CqvT01FLxSyWVR7YTvrSWqfA9946BR97oRi0ZtF3/BH12rv36nUjTa\n9o8E93cCtI/aQDIQyc8rf5f1l1vGIg4lvZWmz1WgbOi9GjvF4Po2+Ug6iMco\nhtIrLpg/TINSQiQaQwphpeijtHdtqO+PJjVnlfUYRlhoOF3EJBYCFD79IfOh\n9nrD0AIeOI5mQI+/z2Z0/neIRdeRV4aGBxACHScqT54KWpApWMp+ozw87uB4\npVpus3aXuwo153usMLJWx7tgh+aPVnm07n4ti/f6vLa5BycfXR83PYjwCaDx\nmcLxAeECCEBl1jFuwnKxWCHKviJFWLTyh66U9Ater3+oBXpXtXjX1LV628j6\n8ubd9bV6jS9Xsrm+endVyeu36vL6DWh78+5qYXQ1bq2NDOEOAK1dE+a+evn5\n+kQ9qronJ+7Q9J5QuoM5jVJSqcyZvBs4S20vku4R29buYdKyA2s9UuxorMma\nolN3xYNAQkX25+LvaEAZPgSvjaMOZF3DfNTcTalH4CiNCkbCk5TMhqFxmcbA\nlsfAp4JgfZhMmsxjekCWOPsjLivv+s1SvDrEBJ8JAb7CexbMUOo6nZA6OhHT\nGGWozPm8VJCqQyCIdA1PIRGQoxFQXhZO5+KzeyAI+q5S8D0/Hxg9WOF2hyYG\nQic3uLAbZ08jBsxtKuSk/RrLy36qqgBc0pgCeS1qQDL6xdJEKQ2EKA8BdDSD\nlJoZGL2CuK2e7ZAT3L9yoyQuDKUaKJfU4jcbQ46RDpDs5JMFxtNanEEPWKtA\ngiFnWaCC632tzrPyEB53HRyE9PTG8O5D5cEnJS7R8kVZ+EKcNak3nLPSvQhr\n3Ub+BUVbTmPk7pXaQAlpHgqEfmLshKHQ3bI57cjSs1cUYIZXIHiA7NGJFG+j\n21YRq8UL+oW8fFHm30bGMtoVRqGuj9xDhjj/6C27OcBZTNOVKeGZimvC0bMO\nCOhZXGMabJA1kApqEzhRPFOEBD39PAuyTWMFprboHQ5okkrTiA1hq3rq/R6i\nSiua1K6pQkLMDKzzsK33ZnznqXy5N9iAXVtVxqeU77tU4LhGHGEcfW77KmuA\nV0ZGVphErc+FQEzmMqnJClJTxj5K210WZwgmcosB+ycTH5oUD/Qor81c5tbI\nKPBJrC5DBqKXNiDFIRvL1HmihA4r6DQvPy30N5om1oTdxutO+tLRysnzXHY0\nnmjWGro6eo+RDvtC9Dz+nwF/64ZArEq1mAa982E0nQrt3nV5CgyF2wpX/QcD\nRaAJFDf3ByuohkftB0goPLLBvWOfmSRWQ6HnvFn1GE9GZLRFgzyqPezHUakp\nMl/2Dsko9aBySxmMn0wP3qPeHbUmr0lpFiLdpuhG6RRNgbKOkM4HngqjCHKH\nLHxLAafRxu/YvBveZox1n44PJamBLtFplqcCHJaNb0kmxbvnbgNtGuuE3oIc\n1oiKiUS0UtvSCrlqClSZSxmvA5gufiouMy2uPW+eL6rBM5qSCwnHdsXyX3oW\n723GYbApAz3NkbhebLXrg9k9Y31M3Z//n/Wy8Tm784PR9oIvyvs7yrU0h1JM\nno02WY/OmcC40WFWbSbxDH13L8aiJHsPqWT3XttMiyQVCtys+c1aGe2ldawT\nubmlQobSYD7W8TQMySdx5xmXTpAotweVJ44iH4QMzdg5wOxZGeyOi97haPWp\njIHpfURq2kRLmEivAbVN5qcaOL7NQTDlLZpR6RpGnThd2PZGyvEtUDgqeHs4\nTlD+udBOEt9Kvp+cq6c39+H9Z95V7g0zvtvsd5gNJvmEMBu6mN5nMGnMcvTD\nyx2CbOTWWdLjRDGenmdyu/5x1MkpW4abM+xipiRBmLSMoNIk3igDtZ1lj546\ni5on9iN1s1njdzMaRLnOWHhYj1Yle1bR/EFZRZOi0PPOyeVqNl4AofRihiCH\nc8+T5ub79f8AH14y9g==\n".decompress ##REPLACE#SKELFILE##
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
      schema = YAML.safe_load "eJzVV0tv4zYQvvtXDNQcklSK0rTOQZcCu70UCNA97C2wDVoaSVxTpEpSm3XR\nH19SD8uSKdkJdrFbAYZJznDmmweHwyAIFt4VTbwIcq1LFYUh2eWikvvHcEvi\nXZwTyu9UnGNB7j4pwRdhCN5Vs3C0yZKClk3ILEwkSXX4cP9wH/zyEDaEhaaa\nYQTvOrnwXvCUZpUkmhrJel8aqth+wlgvJP5dUYlJBM9MxDWD8gG/YFzZ8UZL\nxNWCJAm1U8I+SFGi1BRVBClhChdlv7IAkGrP402CKamYrlfA2CExNUZ4P4VX\nhqLCmkmUWnmGflDbMCeoYklLuxLBE1UaRArWRVUJmsgMtQItQCEz8CGVogDC\nE9A5UmlWtaY8U7WkgZ12oSRao+QfBoBrgHe3XjfuEVgA7xrFH2vF8NRChT8w\npbz2yGHXiTb7HXlXCqFXB8KcQzue8gRnLdLIOZ53mpWWxvIBobU3gvX19e/R\n8zpc3YY3tzfXd7c3V0eMCVW7oUTB8a90uAQQtIq2QjAkfII6csCsxGbfkY9I\npUUhKq59qCqarBz8l7lu4AWnGwcSO7VTDDBrev/FJot1BFpWbihQm3VOiyOS\nx18qZEGMFitqgikmfJOqePd2e4Lv4+bJNOlxXRYJ+7XRmIY8FHnG7ccSlSbb\n/2mAc5rlzPz0JhZMyAsrCfKqMOdzy0w59M2JTXzIzMXAfdgjY+LFhy2r0IeC\nZMg18SHeE0N8yak2q+1t4EOjuJXSTGpZzbCV2Ew6ud0WK70ZH3S0ZtSamnGr\nL5NkXwPcH1cQpXKXtY6CdWnqE753lcnRlcrGZWzAIbEQGocs00cpNpuM8dRA\nOQ39bAF+zXF22nWCvFIoXRV6wLTDfUoZnvLNlwsr253bZ05Qq+9Ney++MGc6\nie7z1td17P9t4ntz5b0yXse3YpI4HP2agM4728p/o8PaUjVRhc5U8wBo+fm3\nefLjDDkXSnNSTNd2IyHhwQxbKeQE+MZyyjVmKJ0chWkAC1sV791k8qUhPy6X\nvy4Ny7CldvS6H3O0F0zfqNvGNxcvtttt2viTLtj85S28BjCRpvTVc1MIi76/\nHTfgPRguEvTM08Que4cG3vbmExDfP/0Jop7XfXhJVP1fbzuPxJFRh0PnrZ/X\nwepnb+Asiy9yt/PnTsBp1ndPjT7mDjy97kyKqhzzjnPCkQeH2D8sl+0iNT41\nnNlY2uj0v/1ZoMxbMsZNKliCciM+o5Q0GdXB2bb+5JSbyOtW3td9bzRPxDaH\nNgWabB4qmLhX55+RLpt4xdikYrePvoVuUelMfMvg25TdFGJsy7l2LjUQrRk+\nqJym2g5XUyl1keSSSMIYMvqPE8lpN/rdUqGtoS6UfeXqvkEFm0V29jXhgD6u\nxT1zSiizWfpDwvwPa8DTag==\n".decompress ##REPLACE#SCHEMAFILE##
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