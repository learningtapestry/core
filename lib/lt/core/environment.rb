require 'yaml'
require 'erb'
require 'log4r'
require 'log4r/yamlconfigurator'
require 'ostruct'
require 'erubis'

module LT
  class << self
    attr_accessor :environment

    def env
      environment
    end
  end

  class Environment
    # run_env holds running environment: production|staging|test|development
    # root_dir holds application root (where this Rake file is located)
    # model_path holds the folder where our models are stored
    # test_path holds folder where the tests are stored
    attr_accessor :run_env, :logger, :root_dir, :model_path, :config_path,
      :test_path, :seed_path, :lib_path, :db_path, :tmp_path, :log_path,
      :message_path, :janitor_path, :web_root_path, :web_asset_path, :partner_lib_path,
      :pony_config, :merchant_config, :local_tmp, :local_log

    def initialize(app_root_dir)
      setup_environment(app_root_dir)
      init_logger
      boot_db(File::join(config_path, 'config.yml'))
      LT::RedisServer::boot(YAML::load_file(File::join(config_path, 'redis.yml'))[run_env])
      configure_mailer
      configure_merchant
      load_all_models
      require_env_specific_files
      logger.info("Core-app booted (mode: #{run_env})")
    end

    def self.boot_all(app_root_dir = File::join(File::dirname(__FILE__),'..'))
      LT.environment = Environment.new(app_root_dir)
    end

    def env?(type)
      (self.run_env == (type && ENV['RAILS_ENV'] = type))    
    end

    def testing?
      # we are only in a testing environment if RAILS_ENV and run_env agree on it
      env?('test')
    end

    def development?
      # we are only in a development environment if RAILS_ENV and run_env agree on it
      env?('development')
    end

    def production?
      env?('production')
    end

    # raise an exception if we are not in testing mode
    def testing!(msg="Expected to be in testing env, but was not.")
      raise LT::Critical.new(msg) if !self.testing?
    end

    def development!(msg="Expected to be in testing env, but was not.")
      raise LT::Critical.new(msg) if !self.development?
    end

    # app_root_dir is the path to the root of the application being booted
    def setup_environment(app_root_dir)
      # null out empty string env vars
      if ENV['RAILS_ENV'] && ENV['RAILS_ENV'].empty? then
        ENV['RAILS_ENV'] = nil
      end
      if ENV['RACK_ENV'] && ENV['RACK_ENV'].empty? then
        ENV['RACK_ENV'] = nil
      end
      self.run_env = ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      ENV['RAILS_ENV'] = run_env
      Rails.env = run_env if defined? Rails
      self.root_dir = File::expand_path(app_root_dir)
      self.model_path = File::expand_path(File::join(root_dir, '/lib/models'))
      self.lib_path = File::expand_path(File::join(root_dir, '/lib'))
      self.test_path = File::expand_path(File::join(root_dir, '/test'))
      self.config_path = File::expand_path(File::join(root_dir, '/config'))      
      self.db_path = File::expand_path(File::join(root_dir, '/db'))      
      self.seed_path = File::expand_path(File::join(root_dir, '/db/seeds'))
      self.janitor_path = File::expand_path(File::join(lib_path,'/janitors'))
      self.web_root_path = File::expand_path(File::join(root_dir, '/web-public'))
      self.web_asset_path = File::expand_path(File::join(web_root_path, '/assets'))
      self.local_tmp = File::expand_path(File::join(root_dir, '/tmp'))
      self.tmp_path = File::exists?(local_tmp) ? local_tmp : Dir::tmpdir
      self.local_log = File::expand_path(File::join(root_dir, '/log'))
      self.log_path = File::exists?(local_log) ? local_log : tmp_path
      self.message_path = File::expand_path(File::join(root_dir, '/log/messages'))
      unless File.directory?(message_path)
        FileUtils.mkdir_p(message_path)
      end
    end

    def load_all_models
      models = Dir::glob(File::join(model_path, '*.rb'))
      models.each do |file| 
        full_file =  File::join(model_path, File::basename(file))
        require full_file
      end
    end

    def require_env_specific_files
      # Note to future self: do not create production specific requirements
      if development? then
        require 'pry'
        require 'pry-stack_explorer'
        require 'byebug'
      end
    end

    def boot_db(config_file)
      # Connect to DB
      begin
        boot_ar_config(config_file)
        dbconfig = YAML::load(File.open(config_file))
        # TODO:  Need better error message of LT::run_env is not defined; occurred multiple times in testing
        ActiveRecord::Base.establish_connection(dbconfig[run_env])
      rescue Exception => e
        logger.error("Cannot connect to Postgres, connect string: #{dbconfig[run_env]}, error: #{e.message}")
        raise e
      end
    end

    def boot_ar_config(config_file)
      # http://stackoverflow.com/questions/20361428/rails-i18n-validation-deprecation-warning
      # SM: Don't really know what this means - hopefully doesn't matter
      I18n.config.enforce_available_locales = true
      ActiveRecord::Base.configurations = ActiveRecord::Tasks::DatabaseTasks.database_configuration = YAML::load_file(config_file)
      ActiveRecord::Tasks::DatabaseTasks.db_dir = db_path
      ActiveRecord::Tasks::DatabaseTasks.env    = run_env
      #If you need to customize AR model pluralization do it here
      ActiveSupport::Inflector.inflections do |inflect|
        #inflect.irregular 'weird_singular_model_thingy', 'wierd_plural_model_thingies'
      end
    end

    def get_db_name
      return ActiveRecord::Base.connection_config[:database]
    end
    
    def ping_db
      begin
        return ActiveRecord::Base.connection.active?
      rescue
        return false
      end
      return false
    end

    def configure_mailer
      @pony_config = YAML::load(File.open(File::join(config_path, 'pony.yml')))[run_env]
      @pony_config.deep_symbolize_keys!
    end

    def configure_merchant
      @merchant_config = YAML::load(File.open(File::join(config_path, 'merchant.yml')))[run_env]
      @merchant_config.deep_symbolize_keys!
    end

    def run_tests(path=nil)
      path ||= test_path
      test_file_glob = File::expand_path(File::join(path, '**/*_test.rb'))
      testfiles = Dir::glob(test_file_glob)
      testfiles.each do |testfile|
        run_test(testfile, path)
      end
    end

    # will test a single file in test folder
    # test file must self-run when "required"
    # TODO: Fix Rake which calls this function with a different signature
    def run_test(testfile, test_path)
      testing!
      # add testing path if it is missing from file
      if testfile == File::basename(testfile) then
        testfile = File::join(test_path, File::basename(testfile))
      end
      #TODO: This should be load not require I think (for re-entrant code running)
      require testfile
    end # run_test

    # will initialize the logger
    def init_logger
      # prevent us from re-initializing the logger if it's already created
      return if self.logger.kind_of?(Logger)

      # Attempt to load configuration file, if doesn't exist, use standard output
      log4r_config_file = File.expand_path(config_path + "/log4r.yml")
      if File.exist?(log4r_config_file) then
        processed = Erubis::Eruby.new(File.read(log4r_config_file)).result(tmp_path: tmp_path, run_env: run_env)
        log4r_config = YAML.load(processed)
        Log4r::YamlConfigurator.decode_yaml(log4r_config['log4r_config'])
        self.logger = Log4r::Logger[run_env]
      else
        self.logger = Log4r::Logger.new(run_env)
        self.logger.level = Log4r::DEBUG
        self.logger.add Log4r::Outputter.stdout
        self.logger.warn "Log4r configuration file not found, attempted: #{config_path + "/log4r.yml"}"
        self.logger.info "Log4r outputting to stdout with DEBUG level."
      end
    end

    # debug tools to permit running test code and having other parts of the application
    # know to run a break point. This allows breaking out only during a specific test case
    # even if the same point of code is accessed many times during the test.
    def debug
      @debug = true
      yield
      @debug = false
    end
    
    def debug!
      byebug if @debug
    end
  end
end
