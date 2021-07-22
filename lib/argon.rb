# frozen_string_literal: true

require 'argon/version'
require 'argon/error'
require 'argon/invalid_transition_error'
require 'argon/invalid_parameter_error'
require 'pry-byebug'

module Argon
  attr_reader :state

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def state_machine(field, &block)
      self.instance_eval(&block)
      debugger
    end

    private

    def start_at(start_state)
      @start_state = start_state
    end

    def on(event_name, mapping)
      @states ||= []
      @events = {}
      raise Argon::InvalidParameterError unless mapping.is_a?(Hash)
      raise Argon::InvalidParameterError unless mapping.keys.count == 1
      
      from_states = mapping.keys.first
      raise Argon::InvalidParameterError unless from_states.is_a?(Array)
      raise Argon::InvalidParameterError unless from_states.map{|s| s.class.name}.uniq == ['Symbol']
      @states.append(*from_states)
      @states.uniq!

      to_state = mapping[from_states]
      raise Argon::InvalidParameterError unless to_state.is_a?(Symbol)
      @states << to_state
      @states.uniq!

      @events[event_name] = {from: from_states, to: to_state}
    end
  end
end
