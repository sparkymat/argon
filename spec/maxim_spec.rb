require 'spec_helper'

RSpec.describe Maxim do
  it 'has a version number' do
    expect(Maxim::VERSION).not_to be nil
  end

  context 'checks params structure' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should not allow without args' do
      expect {
        class SampleClass
          include Maxim
          state_machine
        end
      }.to raise_error(ArgumentError)
    end

    it 'should not allow on non-Hash' do
      expect {
        class SampleClass
          include Maxim
          state_machine :state
        end
      }.to raise_error(Maxim::Error, "status_machine() has to be called on a Hash")
    end

    it 'should only allow a field and mappings' do
      expect {
        class SampleClass
          include Maxim
          state_machine state: :foo
        end
      }.to raise_error(Maxim::Error, "status_machine() has to specify a field and the mappings")
    end

    it 'should only allow states, events, edges and transition callbacks' do
      expect {
        class SampleClass
          include Maxim
          state_machine state: {
            foo: 1,
            bar: 2,
          }
        end
      }.to raise_error(Maxim::Error, "status_machine() should have (only) the following mappings: states, events, edges, on_successful_transition, on_failed_transition")
    end

    it 'should only allow Hash for states' do
      expect {
        class SampleClass
          include Maxim
          state_machine state: {
            states: {
              foo: 1,
              bar: 2,
            },
            bar: 2,
          }
        end
      }.to raise_error(Maxim::Error, "status_machine() should have (only) the following mappings: states, events, edges, on_successful_transition, on_failed_transition")
    end

    it 'should not allow empty states definitions' do
      expect {
        class SampleClass
          include Maxim
          state_machine state: {
            states:                   {},
            events:                   2,
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`states` does not specify any states")
    end

    it 'should only allow state mappings to non Integers' do
      expect {
        class SampleClass
          include Maxim
          state_machine state: {
            states: {
              foo: 'hello',
              bar: 4.7,
            },
            events:                   2,
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`states` must be a mapping of Symbols to unique Integers")
    end

    it 'should not allow state mappings from non-Symbols' do
      expect {
        class SampleClass
          include Maxim
          state_machine state: {
            states: {
              1   => 1,
              nil => 2,
            },
            events:                   2,
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`states` must be a mapping of Symbols to unique Integers")
    end

    it 'should only allow unique Integer mappings for states' do
      expect {
        class SampleClass
          include Maxim
          state_machine state: {
            states: {
              foo: 1,
              bar: 1,
            },
            events:                   2,
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`states` must be a mapping of Symbols to unique Integers")
    end

    it 'should prevent clashes between existing singelton methods and state scope methods' do
      expect {
        class SampleClass
          include Maxim

          def self.foo
          end

          state_machine state: {
            states: {
              foo: 1,
              bar: 2,
            },
            events:                   2,
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`foo` is an invalid state name. `SampleClass.foo` method already exists")
    end

    it 'should prevent clashes between existing instance methods and state check methods' do
      expect {
        class SampleClass
          include Maxim

          def foo?
          end

          state_machine state: {
            states: {
              foo: 1,
              bar: 2,
            },
            events:                   2,
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`foo` is an invalid state name. `SampleClass#foo?` method already exists")
    end

    it 'should only allow events as an array of Symbols' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              foo: 1,
              bar: 2,
            },
            events:                   2,
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`events` should be an Array of Symbols")
    end

    it 'should prevent clashes between existing instance methods and event methods' do
      expect {
        class SampleClass
          include Maxim

          def foo
          end

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
              :foo,
              :bar
            ],
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`foo` is not a valid event name. `SampleClass#foo` method already exists")
    end

    it 'should only allow edges as an Array of Hashes' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges:                    3,
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`edges` should be an Array of Hashes, with keys: from, to, action, post_lock_callback (optional), in_lock_callback (optional), on_events (optional)")
    end

    it 'should only allow edges with the right keys' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: 1, to: 2},
              {from: 1, to: 2, action: 3, foo: 4},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`edges` should be an Array of Hashes, with keys: from, to, action, post_lock_callback (optional), in_lock_callback (optional), on_events (optional)")
    end

    it 'should only allow edges from valid states' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: 1, to: 2, action: 3},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`edges[0].from` is not a valid state")
    end

    it 'should only allow edges to valid states' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: 2, action: 3},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`edges[0].to` is not a valid state")
    end

    it 'should only allow edge action as a valid Symbol' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: 3},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`edges[0].action` is not a Symbol")
    end

    it 'should not allow edge action to conflict with an existing method' do
      expect {
        class SampleClass
          include Maxim

          def foo!
          end

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :foo},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`foo` is an invalid action name. `SampleClass#foo!` method already exists")
    end

    it 'should not allow edge check action to conflict with an existing method' do
      expect {
        class SampleClass
          include Maxim

          def can_foo?
          end

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :foo},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`foo` is an invalid action name. `SampleClass#can_foo?` method already exists")
    end

    it 'should only allow edge in_lock_callback as true' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :ghi, in_lock_callback: 22},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`edges[0].in_lock_callback` is not `true`")
    end

    it 'should only allow edge post_lock_callback as true' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :ghi, post_lock_callback: 22},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`edges[0].post_lock_callback` is not `true`")
    end

    it 'should only allow edge on_events as array of Symbols' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :ghi, on_events: :bar},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`bar` (`edges[0].on_events`) is not a valid list of events")
    end


    it 'should only allow edge on_events from the event list' do
      expect {
        class SampleClass
          include Maxim

          def on_foo(from:, to:, context:)
          end

          def after_foo(from:, to:, context:)
          end

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
              :foo,
            ],
            edges: [
              {from: :abc, to: :def, action: :ghi, on_events: [:bar]},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`bar` (`edges[0].on_events[0]`) is not a registered event")
    end

    it 'should only allow on_successful_transition as a lambda' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :ghi},
            ],
            on_successful_transition: 4,
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`on_successful_transition` must be a lambda of signature `(from:, to:, context:)`")
    end

    it 'should only allow on_successful_transition as a lambda(from:, to:, context:)' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :ghi},
            ],
            on_successful_transition: ->(test:) {},
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`on_successful_transition` must be a lambda of signature `(from:, to:, context:)`")
    end

    it 'should only allow on_failed_transition as a lambda' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :ghi},
            ],
            on_successful_transition: ->(from:, to:, context:) {},
            on_failed_transition:     5,
          }
        end
      }.to raise_error(Maxim::Error, "`on_failed_transition` must be a lambda of signature `(from:, to:, context:)`")
    end

    it 'should only allow on_failed_transition as a lambda(from:, to:, context:)' do
      expect {
        class SampleClass
          include Maxim

          state_machine state: {
            states: {
              abc: 1,
              def: 2,
            },
            events: [
            ],
            edges: [
              {from: :abc, to: :def, action: :ghi},
            ],
            on_successful_transition: ->(from:, to:, context:) {},
            on_failed_transition:     ->(test:) {},
          }
        end
      }.to raise_error(Maxim::Error, "`on_failed_transition` must be a lambda of signature `(from:, to:, context:)`")
    end
  end

  context 'it emulates the enum functionality with symbols' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should generate the state map, getter and scopes' do
      class SampleClass;end

      expect(SampleClass).to receive(:scope).with(:abc, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:def, instance_of(Proc))

      SampleClass.class_eval do
        include Maxim

        state_machine state: {
          states: {
            abc: 1,
            def: 2,
          },
          events: [
          ],
          edges: [
            {from: :abc, to: :def, action: :ghi},
          ],
          on_successful_transition: ->(from:, to:, context:) {},
          on_failed_transition:     ->(from:, to:) {},
        }
      end

      expect(SampleClass.states).to eq({abc: 1, def: 2})

      a = SampleClass.new
      allow(a).to receive(:[]).with(:state).and_return(1)

      expect(a.state).to eq :abc
    end
  end

  context 'edge generation' do
    before do
      class SampleClass
        def initialize
          @state = nil
        end

        def [](field)
          @state
        end

        def update_column(field, value)
          @state = value
        end

        def with_lock(&block)
          block.call
        end
      end

      expect(SampleClass).to receive(:scope).with(:abc, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:def, instance_of(Proc))

      SampleClass.class_eval do
        include Maxim

        state_machine state: {
          states: {
            abc: 1,
            def: 2,
          },
          events: [
          ],
          edges: [
            {from: :abc, to: :def, action: :move},
          ],
          on_successful_transition: ->(from:, to:, context:) {},
          on_failed_transition:     ->(from:, to:, context:) {},
        }
      end

      @instance = SampleClass.new
      @instance.update_column(:state, 1)
      expect(@instance.state).to eq :abc
    end

    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should generate edge methods which transition states' do
      expect { @instance.move! }.to change(@instance, :state).from(:abc).to(:def)
    end

    it 'should generate edge methods which check if transition possible' do
      expect(@instance.can_move?).to eq true
      @instance.update_column(:state, :def)
      expect(@instance.can_move?).to eq false
    end

    it 'should generate edge methods which throw error if state not correct' do
      @instance.update_column(:state, 2)
      expect { @instance.move! }.to raise_error(Maxim::InvalidTransitionError)
    end
  end

  context 'event generation' do
    before do
      class SampleClass
        def initialize
          @state = nil
        end

        def [](field)
          @state
        end

        def update_column(field, value)
          @state = value
        end

        def with_lock(&block)
          block.call
        end
      end

      expect(SampleClass).to receive(:scope).with(:abc, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:def, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:ghi, instance_of(Proc))

      SampleClass.class_eval do
        include Maxim

        def on_foo(from:, to:, context:)
        end

        def after_foo(from:, to:, context:)
        end

        def on_bar(from:, to:, context:)
        end

        def after_bar(from:, to:, context:)
        end

        state_machine state: {
          states: {
            abc: 1,
            def: 2,
            ghi: 3,
          },
          events: [
            :foo,
            :bar,
          ],
          edges: [
            {from: :abc, to: :ghi, action: :move,       on_events: [:foo, :bar]},
            {from: :def, to: :ghi, action: :dont_move,  on_events: [:foo]},
          ],
          on_successful_transition: ->(from:, to:, context:) {},
          on_failed_transition:     ->(from:, to:, context:) {},
        }
      end

      @instance = SampleClass.new
      @instance.update_column(:state, 1)
      expect(@instance.state).to eq :abc
    end

    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should generate event methods which check and transition' do
      expect { @instance.foo! }.to change(@instance, :state).from(:abc).to(:ghi)
    end

    it 'should generate event methods which check and transition' do
      expect { @instance.bar! }.to change(@instance, :state).from(:abc).to(:ghi)
    end

    it 'should generate event methods which check and transition' do
      @instance.update_column(:state, 2)
      expect { @instance.foo! }.to change(@instance, :state).from(:def).to(:ghi)
    end

    it 'should throw exception if generated event method can\'t find a valid edge' do
      @instance.update_column(:state, 2)
      expect { @instance.bar! }.to raise_error(Maxim::InvalidTransitionError, "No valid transitions")
    end

    it 'should throw exception if generated event method has no edges' do
      @instance.update_column(:state, 3)
      expect { @instance.foo! }.to raise_error(Maxim::InvalidTransitionError, "No valid transitions")
    end

    it 'should throw exception if generated event method has no edges' do
      @instance.update_column(:state, 3)
      expect { @instance.bar! }.to raise_error(Maxim::InvalidTransitionError, "No valid transitions")
    end
  end

  context 'callbacks' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should receive callbacks' do
      success = double('callback')
      expect(success).to receive(:call).with(from: :abc, to: :def)

      failure = double('callback')
      expect(failure).to receive(:call).with(from: :def, to: :def)

      class SampleClass
        def initialize
          @state = nil
        end

        def [](field)
          @state
        end

        def update_column(field, value)
          @state = value
        end

        def with_lock(&block)
          block.call
        end
      end

      expect(SampleClass).to receive(:scope).with(:abc, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:def, instance_of(Proc))

      SampleClass.class_eval do
        include Maxim

        def on_foo(from:, to:, context:)
        end

        def after_foo(from:, to:, context:)
        end

        state_machine state: {
          states: {
            abc: 1,
            def: 2,
          },
          events: [
            :foo,
          ],
          edges: [
            {from: :abc, to: :def, action: :move},
          ],
          on_successful_transition: ->(from:, to:, context:) { success.call(from: from, to: to) },
          on_failed_transition:     ->(from:, to:, context:) { failure.call(from: from, to: to) },
        }
      end

      instance = SampleClass.new
      instance.update_column(:state, 1)
      expect(instance.state).to eq :abc
      expect { instance.move! }.to_not raise_error

      instance = SampleClass.new
      instance.update_column(:state, 2)
      expect(instance.state).to eq :def
      expect { instance.move! }.to raise_error(Maxim::InvalidTransitionError, "Invalid state transition")
    end
  end

  context 'callbacks with context' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should receive callbacks' do
      success = double('callback')
      expect(success).to receive(:call).with(from: :abc, to: :def, context: :foobar)

      failure = double('callback')
      expect(failure).to receive(:call).with(from: :def, to: :def, context: :foobar)

      class SampleClass
        def initialize
          @state = nil
        end

        def [](field)
          @state
        end

        def update_column(field, value)
          @state = value
        end

        def with_lock(&block)
          block.call
        end
      end

      expect(SampleClass).to receive(:scope).with(:abc, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:def, instance_of(Proc))

      SampleClass.class_eval do
        include Maxim

        def on_foo(from:, to:, context:)
        end

        def after_foo(from:, to:, context:)
        end

        state_machine state: {
          states: {
            abc: 1,
            def: 2,
          },
          events: [
            :foo,
          ],
          edges: [
            {from: :abc, to: :def, action: :move},
          ],
          on_successful_transition: ->(from:, to:, context:) { success.call(from: from, to: to, context: context) },
          on_failed_transition:     ->(from:, to:, context:) { failure.call(from: from, to: to, context: context) },
        }
      end

      instance = SampleClass.new
      instance.update_column(:state, 1)
      expect(instance.state).to eq :abc
      expect { instance.move!(:foobar) }.to_not raise_error

      instance = SampleClass.new
      instance.update_column(:state, 2)
      expect(instance.state).to eq :def
      expect { instance.move!(:foobar) }.to raise_error(Maxim::InvalidTransitionError, "Invalid state transition")
    end
  end

  context 'in/post lock callbacks' do
    after do
      Object.send(:remove_const, :SampleClass)
    end

    it 'should receive callbacks' do
      class SampleClass
        def initialize
          @state = nil
        end

        def [](field)
          @state
        end

        def update_column(field, value)
          @state = value
        end

        def with_lock(&block)
          block.call
        end
      end

      expect(SampleClass).to receive(:scope).with(:abc, instance_of(Proc))
      expect(SampleClass).to receive(:scope).with(:def, instance_of(Proc))

      SampleClass.class_eval do
        include Maxim

        def on_foo(from:, to:, context:)
        end

        def after_foo(from:, to:, context:)
        end

        state_machine state: {
          states: {
            abc: 1,
            def: 2,
          },
          events: [
            :foo,
          ],
          edges: [
            {from: :abc, to: :def, action: :move, on_events: [:foo], post_lock_callback: true, in_lock_callback: true},
          ],
          on_successful_transition: ->(from:, to:, context:) {},
          on_failed_transition:     ->(from:, to:, context:) {},
        }
      end

      instance = SampleClass.new

      expect(instance).to receive(:on_move).with(hash_including(from: :abc, to: :def, context: :foobar)).twice
      expect(instance).to receive(:after_move).with(hash_including(from: :abc, to: :def, context: :foobar)).twice

      expect(instance).to receive(:on_foo).with(hash_including(from: :abc, to: :def, context: :foobar)).once
      expect(instance).to receive(:after_foo).with(hash_including(from: :abc, to: :def, context: :foobar)).once

      instance.update_column(:state, 1)
      instance.foo!(:foobar)

      instance.update_column(:state, 1)
      instance.move!(:foobar)
    end
  end
end
