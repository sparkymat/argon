# symbolic_enum

`symbolic_enum` is an alternate implementation of [Rails enums](http://api.rubyonrails.org/classes/ActiveRecord/Enum.html), which changes the following:

* The getters return symbols instead of strings.
* Option to mark the field as an array. This assumes that the underlying database column is an integer array.
* Option to disable scopes and/or setters.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'symbolic_enum'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install symbolic_enum

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/symbolic_enum.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
