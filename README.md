# SampleGem

Demonstration Gem - showing what a well formed gem looks like.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sample-gem', :git => 'git://github.com/learningtapestry/sample-gem'
```

And then execute:

    $ bundle install

## Usage

```ruby
SampleGem::Core::init
# => "Init complete"
SampleGem::Core::VERSION
# => "0.0.1"
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/sample-gem/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
