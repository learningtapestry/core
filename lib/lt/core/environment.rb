require 'yaml'
require 'erb'
require 'log4r'
require 'log4r/yamlconfigurator'
require 'ostruct'
require 'dotenv'
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

    # Holds running environment: production|staging|test|development
    attr_accessor :run_env

    # Holds root application directory
    attr_accessor :root_dir

    # Environmental files
    attr_accessor :global_env_path, :specific_env_path, :local_env_path

    # Application paths
    attr_accessor :model_path, :config_path, :test_path, :seed_path, :lib_path,
      :db_path, :message_path, :janitor_path, :partner_lib_path, :web_root_path,
      :web_asset_path
    attr_reader :log_path

    # Redis instance
    attr_accessor :redis

    # Logger instance
    attr_accessor :logger

    # Application configurations
    attr_accessor :pony_config, :merchant_config, :log4r_config, :redis_config

    def initialize(root_dir, env = 'development')
      self.root_dir = File.expand_path(root_dir)
      self.run_env = env

      setup_environment

      Dotenv.overload(local_env_path, specific_env_path, global_env_path)
    end

    def self.boot_all(app_root_dir, env = 'development')
      env = Environment.new(app_root_dir, env)

      env.init_logger
      env.load_all_configs
      env.boot_db('config.yml')
      env.boot_redis('redis.yml') if env.redis_config
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

    def tmp_path=(path)
      @tmp_path = path if File.exists?(path)
    end

    def tmp_path
      @tmp_path ||= Dir.tmpdir
    end

    def log_path=(path)
      @log_path = File.exists?(path) ? path : tmp_path
    end

    def setup_environment
      self.global_env_path = File.join(root_dir, '.env')
      self.local_env_path = File.join(root_dir, '.env.local')
      self.specific_env_path = File.join(root_dir, ".env.#{run_env}")
      self.lib_path = File.join(root_dir, 'lib')
      self.model_path = File.join(lib_path, 'models')
      self.test_path = File.join(root_dir, 'test')
      self.config_path = File.join(root_dir, 'config')
      self.db_path = File.join(root_dir, 'db')
      self.seed_path = File.join(db_path, 'seeds')
      self.janitor_path = File.join(lib_path,'janitors')
      self.partner_lib_path = File.join(root_dir, 'partner-lib')
      self.web_root_path = File.join(root_dir, 'web-public')
      self.web_asset_path = File.join(web_root_path, 'assets')
      self.log_path = File.join(root_dir, 'log')
      self.tmp_path = File.join(root_dir, 'tmp')
      self.message_path = File.join(log_path, 'messages')
      FileUtils.mkdir_p(message_path) unless File.directory?(message_path)
    end

    def load_all_models
      models = Dir::glob(File::join(model_path, '*.rb'))
      models.each do |file| 
        full_file =  File::join(model_path, File::basename(file))
        require full_file
      end
    end

    def boot_db(file)
      ActiveRecord::Base.configurations = db_config(file)

      ActiveRecord::Base.establish_connection(DatabaseTasks.env.to_sym)
    rescue => e
      logger.error("Cannot connect to DB, error: #{e.message}")
      raise e
    end

    def boot_redis(config_file)
      @redis ||= RedisWrapper.new(redis_config)
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

    def load_all_configs
      self.redis_config = load_file_config('redis.yml')
      self.pony_config = load_file_config('pony.yml')
      self.merchant_config = load_file_config('merchant.yml')
    end

    # will initialize the logger
    def init_logger
      self.log4r_config = load_file_config('log4r.yml')

      if log4r_config
        Log4r::YamlConfigurator.decode_yaml(log4r_config['log4r_config'])
        self.logger = Log4r::Logger[run_env]
      else
        self.logger = Log4r::Logger.new(run_env)
        self.logger.level = Log4r::DEBUG
        self.logger.add Log4r::Outputter.stdout
        self.logger.warn
          "Log4r configuration file #{full_config_path('log4r.yml')} not found."
        self.logger.info "Log4r outputting to stdout with DEBUG level."
      end
    end

    def load_file_config(file)
      path = full_config_path(file)
      return unless File.exist?(path)

      load_config(path)
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
      DatabaseTasks.database_configuration = { run_env => load_config(path) }
    end

    def load_config(path)
      YAML.load(ERB.new(File.read(path)).result(binding))
    end
  end
end
