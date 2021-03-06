# Argon

Argon is a workflow engine for Rails, built around a state machine. It relies on a `state` propery on a model to manage workflow around state transitions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'argon'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install argon

## Usage

The `Argon` module provides a `state_machine` class method which expects the following args (as demonstrated by the example below).

```ruby
  class Report
    include Argon

    def on_cancel(action:, message:)
      # This is called from inside the lock, after the edge transitions, with the name of the action. If an exception is thrown here, the entire transition is rolled back
    end

    def after_cancel(action:, message:)
      # This is called after a successful transition, with the action which actually succeeded
    end

    state_machine state: {
      states: {
        draft:     0,
        submitted: 1,
        approved:  2,
        rejected:  3,
        cancelled: 4,
      },
      events: [
        :cancel,
      ],
      edges: [
        { from: :draft,     to: :submitted, action: :submit,           callbacks: {on: false, after: false}                                                     },
        { from: :draft,     to: :cancelled, action: :cancel_draft,     callbacks: {on: false, after: false}, on_events: [:cancel], parameters: [:message_param] },
        { from: :submitted, to: :cancelled, action: :cancel_submitted, callbacks: {on: false, after: false}, on_events: [:cancel], parameters: [:message_param] },
      ],
      parameters: {
        message_param: {
          name:   :message,
          check:  ->(message) { !message.nil? },
        }
      },
      on_successful_transition: ->(from:, to:) { /* Do something here */ },
      on_failed_transition:     ->(from:, to:) { /* Do something else */ },
    }
  end
```

`Report#state` will now return one of `:draft`, `:submitted`, `:approved`, `:rejected` or `:cancelled`. There is no method to set the state directly, and it is recommended to set the numberical value of the initial state (e.g. `0` here for `:draft`) as the default value of the `state` column for the `reports` table, which should be an integer column.

This will generate the following methods for the states:

* `Report.draft`, `Report.submitted`, `Report.approved`, `Report.rejected`, and `Report.cancelled` : These are scopes similar to the ones generated by Rails enum
* `Report#draft?`, `Report#submitted?`, `Report#approved?`, `Report#rejected?`, and `Report#cancelled?` : These are query methods similar to the ones generated by Rails enum

The following methods are generated from the edges:

* `Report#submit!` : This will move the state to `submitted` if the object was in the `draft` state. The state change is done inside a lock (`ActiveRecord::Locking::Pessimistic#with_lock`). If `callbacks.in` was true, then `Report#on_submit` is called from within the lock. If `callbacks.post` was true, then `Report#after_submit` will be called, after the lock is released. Note that if enabled, the callbacks have to be defined before `state_machine` is called, or an exception will be raised.
* `Report#can_submit?` : This will return `true` if the object was in the `draft` state.

  (similar methods are created for `cancel_draft` and `cancel_submitted`)

The following method will be generated for the event:

* `Report#cancel!` : This will check `can_cancel_draft?`, and if true, will call `cancel_draft!`. Else, it will try `can_cancel_submitted?`, and call `cancel_submitted!` if true, and so on. Note that for event methods, both callbacks are mandatory (i.e. here, both `on_cancel` and `after_cancel` must be defined before `state_machine` is called).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sparkymat/argon. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Argon project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/sparkymat/argon/blob/master/CODE_OF_CONDUCT.md).
