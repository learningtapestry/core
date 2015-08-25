require 'minitest/autorun'
require 'rack/test'
require 'nokogiri'
require 'database_cleaner'
require 'capybara'
require 'capybara/poltergeist'
require 'benchmark'
require 'lt/core'

module LT
  module Test
    class TestBase < Minitest::Test
      # method provides a block level way to temporarily set log level
      # to whatever level is desired, and automatically resets it
      # back to the original setting when finished
      def suspend_log_level(new_level = Log4r::FATAL)
        # set logging to critical to avoid reporting an error that is intended into the output
        orig_log_level = LT.environment.logger.level
        LT.environment.logger.level = new_level
        yield
        LT.environment.logger.level = orig_log_level
      end
    end

    # Allows testing Redis Access in isolation
    class RedisTestBase < TestBase
      def connection
        LT.env.redis.connection
      end

      def setup
        LT.env.boot_redis(File::join(LT.env.config_path, 'config.yml'))
      end
    end

    # provides for transactional cleanup of activerecord activity
    class DBTestBase < TestBase
      def initialize(*opts)
        super(*opts)

        setup_db_cleaner
      end

      def setup
        setup_db_cleaner

        super
      end

      def teardown
        super

        DatabaseCleaner.clean
      end

      def setup_db_cleaner
        setup_db_cleaner_pg
        setup_db_cleaner_redis if LT.env.redis_config

        DatabaseCleaner.start
      end

      def setup_db_cleaner_pg
        DatabaseCleaner[:active_record].strategy = :transaction
      end

      def setup_db_cleaner_redis
        DatabaseCleaner[:redis].strategy = :truncation
        DatabaseCleaner[:redis, { connection: LT.env.redis.connection_string }]
      end
    end

    # provides for Sinatra compatibility
    class WebAppTestBase < DBTestBase
      include Rack::Test::Methods

      def self.register(cls)
        cls.registered(self)
      end

      def self.helpers(cls)
        include cls
      end

      def app
        raise NotImplementedError
      end

      def assert_200(msg="")
        assert_equal(200, last_response.status, msg)
      end

      def assert_302(redirection_path, msg="")
        assert_equal(302, last_response.status, msg)
        redirection_regex = %r{:\/\/[^/]+#{redirection_path}}
        assert_match(redirection_regex, last_response.location)
      end

      def get_cookie(cookie)
        cookies = CGI::Cookie::parse(last_response.header['Set-Cookie'])
        cookies[cookie].empty? ? nil : cookies[cookie]
      end

      def get_html
        Nokogiri.parse(last_response.body)
      end
    end

    # this test class is used to drive a headless phantomJS browser
    # for full front-end testing, including javascript
    class WebAppJSTestBase < WebAppTestBase
      include Capybara::DSL

      def use_selenium
        Capybara.default_driver = :selenium
        Capybara.reset_sessions!
        Capybara.current_session.driver.reset!
        Capybara.use_default_driver
      end

      def use_poltergeist
        Capybara.current_driver = :poltergeist
        Capybara.javascript_driver = :poltergeist
        Capybara.default_driver = :poltergeist
        Capybara.reset_sessions!
        Capybara.current_session.driver.reset!
        Capybara.use_default_driver
      end

      # To use the poltergeist javascript debugger add "page.driver.debug"
      # in test file, *before* the JS code call you want to debug
      # When you run your test, you'll get a new window in chrome.
      # Click the second link on the page that is opened for you in chrome
      # That link opens your code/page - select the JS file from the upper left pull-down
      # Set a breakpoint where you want to intercept the code
      # Press enter in the terminal console where your test is running
      # You'll see the code in the browser stopped on the line you breakpointed.
      # more info here: http://www.jonathanleighton.com/articles/2012/poltergeist-0-6-0/
      def use_poltergeist_debug
        Capybara.current_driver = :poltergeist_debug
        Capybara.javascript_driver = :poltergeist_debug
        Capybara.default_driver = :poltergeist_debug
        Capybara.reset_sessions!
        Capybara.current_session.driver.reset!
        Capybara.use_default_driver
      end

      def setup
        super
        Capybara.app = app
        # we create a new driver which is the debug mode for poltergeist
        Capybara.register_driver :poltergeist_debug do |app|
          Capybara::Poltergeist::Driver.new(app, {:inspector => true, :timeout=>999})
        end
        # use_selenium
        # use poltergeist
        use_poltergeist_debug
      end

      def teardown
        super
        Capybara.reset_sessions!
        Capybara.current_session.driver.reset!
        Capybara.use_default_driver
      end
    end # WebAppJSTestBase
  end
end
