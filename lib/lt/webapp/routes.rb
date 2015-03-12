module LT
  module WebApp
    module Routes
      UI_KEY = 'uid'

      module Helpers
        # Purpose: Generate relative links, including any needed parameters for that route
        #   Use in views and other places where user-specific links to resources are needed
        def vlink(base_path, parameters={})
          parameters = parameters.dup
          array_delimiter = parameters.has_key?(:array_delimiter) ?
            parameters.delete(:array_delimiter) : ','
          if array_delimiter
            parameters.select { |k,v| v.kind_of?(Array) }.each do |k,v|
              if v.empty?
                parameters.delete(k)
              else
                parameters[k] = v.join(array_delimiter)
              end
            end
          end
          path = vroute(base_path)
          # Replace named parameters in the route pattern.
          path.scan(/(:\w+)/).each do |m|
            # First item of the match tuple, minus the colon, as a sym ([':param',] -> :param)
            key = m[0][1..-1].to_sym 
            # Delete the named param from the parameters hash,
            # which we'll later merge into the URL query string for the remaining params.
            # Replace the named parameter with its value.
            if parameters.has_key?(key)
              val = parameters.delete(key)
              path.sub!(m[0], val.to_s)
            end
          end
          # If uid = true, fetch the session uid.
          # If uid = something else, use it as the uid.
          # If there's no uid, don't do anything.
          if parameters[:uid]
            parameters.delete(:uid) if parameters[:uid] == true
            parameters.merge!({UI_KEY=>get_ui_id})
          end
          parameters = Rack::Utils.build_nested_query(parameters)
          parameters = nil if parameters.empty?
          request_uri = URI::HTTP::build([nil, nil, nil, path, parameters, nil]).request_uri
          request_uri.gsub('%2C', ',') if array_delimiter == ','
        end

        def vroute(base_path)
          self.class.vroute(base_path)
        end

        # Purpose: Retrieve persistent session/search elements
        #          that work independently for each window/tab
        # Function: Obtains the ui key from params UI_KEY.
        #           Pulls the session hash from Redis based on this key.
        #           If no param UI_KEY exists, it creates one.
        #           If no hash exists in redis, it creates one.
        # Notes: Don't use @ui_id outside of debugging - use get/set_persistent_session methods
        # Returns: A hash with session hash from existing session or empty hash
        def get_persistent_session
          # set up UI session, if we don't have one on the URL line
          ui_id = get_ui_id
          LT::RedisServer::get_ui_session(ui_id)
        end

        def reset_persistent_session
          @ui_id = nil
        end
        # Purpose: Set the persistent session into redis
        # Returns: Session hash as sent to redis
        def set_persistent_session(session)
          LT::RedisServer::set_ui_session(get_ui_id, session)
          session
        end

        def get_server_url
          # force https in production, otherwise mirror incoming request
          # we have to mirror incoming port in testing, b/c the port number is always changing
          if LT::production?
            scheme = 'https'
            port = ''
          else
            scheme = request.scheme
            port = ":#{request.port.to_s}"
          end
          "#{scheme}://#{request.host}#{port}"
        end

        def get_ui_id
          session[UI_KEY] = get_new_ui_id unless session.has_key?(UI_KEY)
          @ui_id = session[UI_KEY] 
        end
        def get_new_ui_id
          SecureRandom.urlsafe_base64(32)
        end
      end

      module ClassMethods
        # Purpose: Generate string paths that can be used to associate controller methods
        #   with specific URL paths in Sinatra
        def vroute(base_path, route=nil, redefine=false)
          # rewrite routes here
          case base_path
            when '/'
              base_path = :home
          end

          # remove leading '/' if provided
          if base_path.kind_of?(String) && base_path[0] == '/' then
            base_path = base_path[1..-1]
          end

          base_path = base_path.to_sym unless base_path.kind_of?(Symbol)

          if route
            if (iroutes.has_key?(base_path)) and (iroutes[base_path] != route) and !redefine
              raise(LT::InvalidParameter, "Attempting route redefinition.")
            elsif iroutes[base_path] != route
              iroutes[base_path] = route
              iroutes[base_path].freeze
            end
          end

          return iroutes[base_path].dup if iroutes[base_path]
          raise(LT::InvalidParameter, "Invalid url path in route (#{base_path}).")
        end
      end

      def self.registered(app)
        class << app
          attr_reader :iroutes
          private
          attr_writer :iroutes
        end
        app.extend(ClassMethods)
        app.helpers Routes::Helpers
        app.instance_eval do
          @iroutes = {}
        end
      end
    end # Routes
  end
end
