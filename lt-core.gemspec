# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lt/core/version'

Gem::Specification.new do |spec|
  spec.name          = "lt-core"
  spec.version       = LT::VERSION
  spec.authors       = ["Steve Midgley", "RM Saksida"]
  spec.email         = ["info@learningtapestry.com"]
  spec.summary       = %q{Sample gem summary}
  spec.description   = %q{Sample gem descr}
  spec.homepage      = "http://www.learningtapestry.com"
  spec.license       = "(c) 2015 Learning Tapestry, all rights reservered."
  # include all files required to run
  spec.files         = Dir::glob('lib/**/**').delete_if {|f| !File::file?(f)} << 'Gemfile' << 'Rakefile'
  # put any files in ./bin if you want them auto-installed to path when gem is installed
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  # use add_dependency where this gem needs a gem in order to function
  # spec.add_dependency "gem dependency"
  spec.add_dependency 'activerecord', '~> 4.2.0'
  spec.add_dependency 'edge'
  spec.add_dependency 'log4r', '>= 1.1.10'
  spec.add_dependency 'erubis', '~> 2.7.0'
  spec.add_dependency 'redis', '>= 3.2.0'
  spec.add_dependency 'sinatra', '~> 1.4.5'
  spec.add_dependency 'sinatra-contrib', '~> 1.4.2'
  spec.add_dependency 'sinatra-param', ">= 1.2.2"
  spec.add_dependency 'sinatra-flash', '~> 0.3.0'
  spec.add_dependency 'sinatra-redirect-with-flash', '~> 0.2.1'
  spec.add_dependency 'warden', '~>1.2.3'
end
