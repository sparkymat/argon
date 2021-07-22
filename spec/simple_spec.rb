# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Argon do
  after do
    Object.send(:remove_const, :SampleClass)
  end

  it 'should allow a basic definition' do
    class SampleClass
      include Argon

      state_machine :state do
        start_at :stopped
        on :drive, %i(stopped) => :driving
        on :brake, %i(driving) => :stopped
        on :breakdown, %i(stopped driving) => :broken
      end 

      def after_drive
        puts "started driving"
      end
    end

    p = SampleClass.new

    expect p.state.to equal(:stopped)
  end
end
