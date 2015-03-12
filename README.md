# lt-core

lt-core - LearningTapestry core modules and classes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lt-core', :git => 'git://github.com/learningtapestry/core'
```

And then execute:

    $ bundle install

## Usage

`lib/webapp.rb`:
```ruby
require 'lt/webapp'

class SampleWebApp < LT::WebApp::Base
    get vroute(:home, '/') do
        'Hello world'
    end
end
```

`config.ru`:
```ruby
require 'lt/core'
path = File::expand_path(File::dirname(__FILE__))
LT::Environment.boot_all(path)
require File::join(path, 'lib', 'webapp.rb')
SampleWebApp.boot
run SampleWebApp
```

## Contributing

1. Fork it ( https://github.com/learningtapestry/core/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
