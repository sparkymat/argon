require 'spec_helper'

RSpec.describe Maxim do
  it 'has a version number' do
    expect(Maxim::VERSION).not_to be nil
  end

  it 'behaves as Rails enum' do
    class SampleClass
      include Maxim

      def initialize(state)
        @state = state
      end

      def self.scope(field, block)
      end

      def [](ind)
        return @state if ind == :state
      end

      state_enum state: {
        initialized:      0,
        pending_approval: 1,
        active:           2,
        completed:        3,
      }
    end
    object = SampleClass.new(0)
    expect{ object.state }.to_not raise_error
    expect(object.state).to eq(:initialized)
  end
end
