require 'redis'

module LT
  #
  # Redis Wrapper
  #
  class RedisWrapper
    attr_accessor :connection

    #
    # @param config [Hash] Redis configuration file
    #
    def initialize(config)
      @config = config

      @connection = ::Redis.new(:url => connection_string)
      @connection.ping # connect to Redis server
    end

    def ping
      @connection.ping == "PONG"
    end

    def connection_string
      @config['url']
    end

    # Writes hash to key with expiration of 1 hour
    # Will convert hash to serialized json string if needed
    # Returns true if successful, false otherwise
    def set_ui_session(key, hash, expiration = 60*60*24)
      raise LT::InvalidParameter if !hash.kind_of?(Hash)
      @connection.setex(key, expiration, hash.to_json) == "OK"
    end

    # Returns a hash containing UI if it exists,
    # otherwise returns {}
    def get_ui_session(key)
      hash = @connection.get(key)
      if hash.kind_of?(String)
        hash = JSON.parse(hash)
      else
        hash = {}
      end
      hash
    end
  end
end
