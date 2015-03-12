require 'redis'

module LT
  module RedisServer
    class << self
      def boot(config)
        @redis_url = config['url']
        # Define and connect to server
        @redis = Redis.new(:url => @redis_url)
        @redis.ping # connect to Redis server
      end

      def connection_string
        @redis_url
      end

      def ping
        @redis.ping == "PONG"
      end

      # Writes hash to key with expiration of 1 hour
      # Will convert hash to serialized json string if needed
      # Returns true if successful, false otherwise
      def set_ui_session(key, hash, expiration = 60*60*24)
        raise LT::InvalidParameter if !hash.kind_of?(Hash)
        @redis.setex(key, expiration, hash.to_json) == "OK"
      end

      # Returns a hash containing UI if it exists,
      # otherwise returns {}
      def get_ui_session(key)
        hash = get(key)
        if hash.kind_of?(String)
          hash = JSON.parse(hash)
        else
          hash = {}
        end
        hash
      end

      def get(key)
        @redis.get(key)
      end
    end
  end
end
