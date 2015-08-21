require 'warden'

module LT
  module WebApp
    module Login
      module Helpers
        def warden
          env['warden']
        end

        def warden_options
          env['warden.options']
        end

        def logged_in?
          warden.authenticated?
        end

        def check_authentication
          unless warden.authenticated?
            redirect '/login'
          end
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
        app.use Rack::Session::Cookie, :secret => '3xWmSSa5X65Fyzn4jVwpM73zBtk5aXDn5CHuuQaB'

        app.use Warden::Manager do |manager|
          manager.default_strategies :password
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
      end
    end
  end
end
