require 'sinatra/base'
require 'sinatra/cookies'
require 'sinatra/json'
require 'sinatra/param'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require_relative 'routes'
require_relative 'login'
require_relative 'views'

module LT
  module WebApp
    class Base < Sinatra::Base
      def self.inherited(base)
        load_all_routes
        super(base)
        parent_iroutes = iroutes
        base.instance_eval do
          @iroutes ||= parent_iroutes.dup
        end
      end

      def self.boot
        set :root, LT.environment.lib_path
        
        if LT.environment.testing?
          set :raise_errors, true
          set :dump_errors, false
          set :show_exceptions, false
        elsif LT.environment.development?
          require 'sinatra/reloader'
          register Sinatra::Reloader
          enable :reloader
          also_reload File::join(LT.environment.lib_path, '/views/*.erb')
          # set this to prevent reloading of specific files
          # dont_reload '/path/to/other/file'
        end
        set :public_folder, LT.environment.web_root_path
      end

      def self.load_all_routes
        ['routes/**/*.rb', 'helpers/**/*.rb'].each do |glob|
          Dir[File::join(File.expand_path(LT.env.lib_path), glob)].each { |file| require file }
        end
      end

      register Sinatra::Flash

      helpers Sinatra::Cookies
      helpers Sinatra::JSON
      helpers Sinatra::Param
      helpers Sinatra::RedirectWithFlash

      register LT::WebApp::Routes
      register LT::WebApp::Login
      register LT::WebApp::Views

      # set up UI layout container
      # we need this container to set dynamic content in the layout template
      # we can set things like CSS templates, Javascript includes, etc.
      before do
        @layout = {}
        # get UI session cookie
        @persistent_session = get_persistent_session
      end

      after do
        set_persistent_session(@persistent_session)
      end
    end
  end
end
