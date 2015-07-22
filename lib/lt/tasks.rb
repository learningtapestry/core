require 'term/ansicolor'
require 'open3'

module LT
  module Term class << self
    include ::Term::ANSIColor
  end; end
  module Test class << self
    def run_all_tests
      $LOAD_PATH.unshift(File::expand_path('./test'))
      Dir::glob("test/**/**_test.rb").each do |f|
        file = File::expand_path("./#{f}")
        require file
      end
    end
  end; end
end

require 'lt/core'

#
# LT provided rake tasks. Most of them require each application to implement
# their :boot task.
#
namespace :lt do
  task full_tests: :'test:run_full_tests'

  task tests: :'test:run_tests'

  #
  # TODO - set port/server from environment var
  #
  desc 'Run WebApp server - this starts the webserver'
  task server: :boot do
    rackup_file = File.join(Dir.pwd, 'config.ru')
    Kernel.system("rackup -p 8080 -o localhost #{rackup_file}")
  end

  desc 'Boot up a console with required context'
  task console: :boot do
    require 'irb'
    IRB.setup nil
    IRB.conf[:MAIN_CONTEXT] = IRB::Irb.new.context
    require 'irb/ext/multi-irb'
    IRB.irb nil, self
  end

  desc "Boot up a console with alternative ruby interactive 'pry'"
  task console_pry: :environment do
    begin
      require 'pry'; binding.pry
    rescue LoadError
      LT.env.logger.info('pry is not installed. Dropping into regular console.')
      Rake::Task[:console].invoke
    end
  end

  desc 'Boot Core-app system'
  task :boot do
    LT::Environment.boot_all(Dir.pwd)
  end

  # TODO Remove this if we decide to keep SM's run_all_tests method above
  # require 'rake/testtask'

  # Rake::TestTask.new do |t|
  #   t.libs << 'test'
  #   t.pattern = 'test/**/*_test.rb'
  #   t.verbose = true
  #   # TODO: fix warnings and enable
  #   # t.warning = true
  # end

  namespace :test do

    namespace :db do
      desc 'Configure database for the test environment'
      desc 'Drop test database'
      task drop_db: [:test_environment, 'db:drop']

      desc 'Drop and recreate test database and run migrations'
      task full_reset: [:drop_db, 'db:create', 'db:migrate']
    end

    task :set_test_environment do; ENV['RACK_ENV'] = 'test'; end

    task test_environment: [:set_test_environment, :environment]

    desc 'Run complete test suite including teardown, rebuild & reseed'
    task run_full_tests: [:test_environment, :'db:full_reset'] do
      LT::Test::run_all_tests
    end

    desc 'Run complete test suite w/out DB reset or bundling'
    task :run_tests => [:test_environment, :'db:migrate'] do 
      LT::Test::run_all_tests
    end

    desc 'Runs a single test file'
    task :run_test, [:testfile] => [:test_environment, :'db:migrate'] do |t, args|
      arg_filename = args[:testfile]
      # if we are given a file with no path, search test folder for the file to run
      if arg_filename == File::basename(arg_filename) then
        filename = Dir::glob("test/**/#{arg_filename}*").first
      else
        filename = arg_filename
      end

      system("bundle exec ruby -Ilib -Itest #{filename}")
    end

    desc "Monitor files for changes and run a single test when a change is detected"
    task :monitor => [:test_environment, :'db:migrate'] do |t, args|
      keep_running = true
      last_test_file = nil
      test_file = ""
      puts "\n\n"
      dot = ['.', ' '].cycle
      while keep_running do
        # Loop until interrupted by ctrl-c
        trap("INT") { puts "\nExiting"; keep_running = false; exit;}
        # if ctrl-z is pressed, re-run the last test file
        trap("TSTP") {
          if !last_test_file.nil? then
            puts "\nRe-running last test: #{last_test_file}"
            test_file = last_test_file
          end
        }
        test_list = FileList['test/**/*_test.rb']
        orig_test_dates = {}
        test_list.each do |file|
          orig_test_dates[file] = File.stat(file).mtime
        end
        # loop through test_list looking for date changes
        keep_searching = true
        while keep_searching && keep_running do
          print "\r#{LT::Term::white}***#{LT::Term::reset} Waiting for file changes. (#{Time::now.strftime('%I:%M %p')}), ctrl-z: re-run last, ctrl-c: exit#{dot.next}"
          Kernel::sleep(0.3) # wait 3/10 second between searches for changed files
          test_list.each do |file|
            Kernel::sleep(0.05) # keep the cpu from maxing out
            if orig_test_dates[file] != File.stat(file).mtime
              print "\n",LT::Term::white,"  File change detected: ", LT::Term::bold,"./#{file}",LT::Term::reset,"\n"
              puts "  Time is: #{Time::now}"
              keep_searching = false
              test_file = file
            end
          end
          if !test_file.blank? && keep_running
            full_test_file = File::expand_path(File::join('.',test_file))
            # invoke the test b/c the file has changed
            puts "Running test suite..."
            last_test_file = test_file
            # we capture the output and stream to stdout it line-by-line
            IO.popen("rake lt:test:run_test[#{full_test_file}]").each do |result_line|
              failure_error = result_line.match(/^\s+[0-9]+\) Error:/) || result_line.match(/^\s+[0-9]+\) Failure:/)
              asserts_failed = result_line.match(/runs, ([0-9]+) assertions, ([0-9]+) failures, ([0-9]+) errors/)
              if failure_error then
                puts LT::Term::red+result_line+LT::Term::reset+LT::Term::yellow
              elsif asserts_failed
                asserts = asserts_failed[1]
                failures = asserts_failed[2]
                errors = asserts_failed[3]
                if failures == "0" && errors == "0" then
                  puts LT::Term::reset+LT::Term::green+result_line+LT::Term::reset
                else
                  puts LT::Term::reset+LT::Term::red+result_line
                end
              else
                puts result_line
              end
            end
            print LT::Term::reset
            test_file = ""
          end
        end # while keep_searching... -- change detection loop
      end # while keep_running do -- main loop
    end # task :monitor
  end # test namesapce
end # lt namespace

task :environment do
  env = ENV['RACK_ENV'] || 'development'
  LT.environment = LT::Environment.new(Dir.pwd, env)
  LT.env.boot_db('config.yml')
end

require 'bundler/setup'
load 'active_record/railties/databases.rake'

Rake.application.tasks.select do |task|
  if task.name.start_with?('db:')
    task.enhance [:environment]
  end
end
