require 'warden'
require 'lt/session/signed_cookie'

module LT
  module WebApp
    module Login
      module Helpers
        include LT::Session::SignedHelpers

        def warden
          env['warden']
        end

        def warden_options
          env['warden.options']
        end

        def logged_in?
          # The difference between authenticate? and authenticated?
          # is that the former will run strategies if the user has not yet been
          # authenticated, and the second relies on already performed ones.
          warden.authenticate?
        end

        def check_authentication
          redirect '/login' unless logged_in?
        end

        def check_admin
          unless session_user.admin?
            redirect '/login'
          end
        end

        def session_user
          warden.user
        end
      end

      def self.registered(app)
        app.helpers Login::Helpers
        app.use Rack::Session::Cookie, :secret => LT.env.secret_config['secret_key_base']

        app.use Warden::Manager do |manager|
          manager.default_strategies :rememberable, :password
          manager.failure_app = app
          manager.intercept_401 = false
          manager.serialize_into_session {|user| user.id}
          manager.serialize_from_session {|id| User.find_by(id: id)}
        end

        Warden::Manager.before_failure do |env,opts|
          env['REQUEST_METHOD'] = 'POST'
        end

        Warden::Strategies.add(:password) do
          def valid?
            params['username'] || params['password'] || params['next_page']
          end

          def authenticate!
            if params[:username] =~ /@/
              user = Email.find_by_email(params['username']).user
            else
              user = User.find_by_username(params['username'])
            end
            if user && user.authenticate(params['password'])
              success!(user)
            else
              throw(:warden, previous_page: '/', message: 'We were not able to log you in. Please check your email and password and try again.')
            end
          end
        end

        Warden::Strategies.add(:rememberable) do

          # A valid strategy for rememberable needs a remember token in the cookies.
          def valid?
            @remember_cookie = nil
            remember_cookie.present?
          end

          def authenticate!
            user = User.serialize_from_cookie(*remember_cookie)

            if user
              remember_me(user)
              extend_remember_me_period(user)
              success!(user)
            else
              request.cookies.delete('remember_token')
              return pass
            end

          end

        private

          # Get values from params and set in the resource.
          def remember_me(resource)
            resource.remember_me = remember_me? if resource.respond_to?(:remember_me=)
          end

          # Should this resource be marked to be remembered?
          def remember_me?
            valid_params? && [true, 1, '1', 't', 'T', 'true', 'TRUE'].include?(params[:remember_me])
          end

          # If the request is valid, finally check if params_auth_hash returns a hash.
          def valid_params?
            params.is_a?(Hash)
          end

          def extend_remember_me_period(resource)
            if resource.respond_to?(:extend_remember_period=)
              resource.extend_remember_period = LT::ActiveRecordUtil::Rememberable.extend_remember_period
            end
          end

          def remember_cookie
            cookie = request.cookies['remember_token']
            @remember_cookie ||= Class.new.extend(LT::Session::SignedHelpers).unencrypt_cookie(cookie) if cookie
          end

        end

      end
    end
  end
end
