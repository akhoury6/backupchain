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
      schema = YAML.safe_load "eJzVV0tv2zgQvvtXEGoOSVaK0nSTgy4LtHtZIMD20FtgG7Q0klhTpJYcNfVi\nf/ySeliWTMlO2qK7AgyTnOHMNw8OOUEQLLwLlngRyRFLHYUh3eayUruHcEPj\nbZxTJm50nENBbz5rKRZhSLyLZuFgkyUFLZtUWZgommJ4d3t3G7y9CxvCAhly\niMj7Ti75IEXKskpRZEYy7kpDlZvPEONCwV8VU5BE5InLuGbQPoGvEFd2vEYF\nsFzQJGF2SvlHJUtQyEBHJKVcw6LsVxaEKL0T8TqBlFYc6xVi7FCQGiO8N+GF\noeiwZpIlas/Q92ob5gR0rFhpVyLyyDQSmRLroqokSFUGqAlKooEb+CRVsiBU\nJARzYMqsIjKR6VrSwE67UFJEUOLjAHAN8Oba68Y9AgvgfaP4U62YPLZQye+Q\nMlF7ZL/rSJv9DryrpMTlnjDn0I6nPMJZizRyDuedZo3KWD4gtPZGZHV5+Vv0\ntAqX1+HV9dXlzfXVxQFjwvR2KFEK+DMdLhEStIo2UnKgYoI6csCsxGbfgY9o\nhbKQlUCfVBVLlg7+81w38ILTjQOJndopBjJrev/FJosxIqgqNxRSm3VKiyOS\nh18qVUGNFitqgimmYp3qePt6e4Kf4+bJNOlxnRcJ+7XRmIY8FHnC7YcSNdLN\n/zTAOctybn64jiWX6sxKAqIqzPnccFMOfXNiE59k5mIQPtkB5/LZJxtegU8K\nmoFA6pN4Rw3xOWdoVtvbwCeN4lZKM6llNcNWYjPp5HZbrPRmvNfRmlFrasat\nvkzRXQ1wd1hBtM5d1joK1rmpT8XOVSZHVyofl7EBh4JCIgxZpo9SbDYZ45mB\nchz62QL8kuPstOsIeaVBuSr0gGkLu5RxOOabLxdWtju3T5ygVt+r9p59Yc68\nJLrPW13Wsf+nie/VhffCeB3eiknicPRLAjrvbCv/lQ5rS9VEFTpRzQPCyi+/\nzpMfZsi51ChoMV3bjYREBDNspVQT4BvLmUDIQDk5CvMALGxVvHWT6deG/HB/\n/+5+MSCsMVdAE/2dy9F0lK22qfybsnFv39sR6VmZIvtN0obdhePZ/ykHe9f2\nPYvtAXL5bB/+TUdz1BCYv7zV2yChytwC9dzALfqn/rgX6cEImYBnujS77O17\nGdumTED88PgHkfW8bklKquv/ettpJI7Dta8/3uppFSx/8QbOsvgid2dzKkWO\nU6PruvpAOvD0ujMlq3LMOw6240jsj8HdfXcImPGp4czG0kaZ//oOSZu2OoZ1\nKnkCai2/gFIsGWXsbIdzVPBM5LGV931br6ZbbnNoXYDJ5qGCiSfGfEftsklU\nnE8qdvvoR+iWFWbyRwbfpuy6kGNbTr1sUwPRmuETnbMU7XA5lVJnSS6popwD\nZ387kRw/zH9aKrQ11IWyr1zdN6hgs8hONlYO6ONa3DOnlHGbpf9JmP8C8dkT\nCQ==\n".decompress ##REPLACE#SCHEMAFILE##
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