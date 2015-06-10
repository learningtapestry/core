require 'yaml'
require 'erb'
require 'log4r'
require 'log4r/yamlconfigurator'
require 'ostruct'
require 'erubis'

require 'active_record'
require 'lt/core/seeds'

module LT
  class << self
    attr_accessor :environment

    def env
      environment
    end
  end

  class Environment
    include ActiveRecord::Tasks

    # run_env holds running environment: production|staging|test|development
    # root_dir holds application root (where this Rake file is located)
    # model_path holds the folder where our models are stored
    # test_path holds folder where the tests are stored
    attr_accessor :run_env, :logger, :root_dir, :model_path, :config_path,
      :test_path, :seed_path, :lib_path, :db_path, :tmp_path, :log_path,
      :message_path, :janitor_path, :web_root_path, :web_asset_path, :partner_lib_path,
      :pony_config, :merchant_config, :local_tmp, :local_log, :redis

    def initialize(app_root_dir, env = 'development')
      setup_environment(app_root_dir, env)
    end

    def self.boot_all(app_root_dir, env = 'development')
      env = Environment.new(app_root_dir, env)

      env.init_logger
      env.boot_db('config.yml')
      env.boot_redis('redis.yml')
      env.configure_mailer('pony.yml')
      env.configure_merchant('merchant.yml')
      env.load_all_models
      env.logger.info("Core-app booted (mode: #{env.run_env})")

      LT.environment = env
    end

    def env?(type)
      self.run_env == type
    end

    def testing?
      env?('test')
    end

    def development?
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
    def setup_environment(app_root_dir, env)
      self.run_env = env
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
      self.partner_lib_path = File::expand_path(File::join(root_dir, '/partner-lib'))
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

    def boot_db(file)
      config = db_config(file)

      ActiveRecord::Base.configurations = config
      ActiveRecord::Base.establish_connection(DatabaseTasks.env.to_sym)
    end

    def boot_redis(config_file)
      @redis ||= RedisWrapper.new(load_required_config(config_file))
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

    def ping_redis
      redis.ping
    end

    def configure_mailer(file)
      @pony_config ||= load_optional_config(file)
    end

    def configure_merchant(file)
      @merchant_config ||= load_optional_config(file)
    end

    def load_required_config(file)
      path = full_config_path(file)
      raise LT::FileNotFound.new("#{path} not found") unless File.exist?(path)

      YAML.load_file(path)[run_env].deep_symbolize_keys
    end

    def load_optional_config(file)
      path = full_config_path(file)
      return unless File.exist?(path)

      YAML.load_file(path)[run_env].deep_symbolize_keys
    end

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

    private

    def full_config_path(file)
      File.join(config_path, file)
    end

    def db_config(file)
      path = full_config_path(file)
      raise LT::FileNotFound.new('No DB config found') unless File.exist?(path)

      DatabaseTasks.root = root_dir
      DatabaseTasks.env = run_env
      DatabaseTasks.db_dir = db_path
      DatabaseTasks.migrations_paths = File.join(db_path, 'migrate')
      DatabaseTasks.seed_loader = LT::Seeds
      DatabaseTasks.database_configuration = YAML::load_file(path)
    end
  end
end
