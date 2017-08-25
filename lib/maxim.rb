require 'maxim/version'
require 'maxim/error'
require 'maxim/invalid_transition_error'
require 'active_support/concern'
require 'active_support/inflector'
require 'pry-byebug'

module Maxim
  extend ActiveSupport::Concern

  module ClassMethods
    def state_enum(mapping)
      raise Maxim::Error.new("status_enum called on bad params") unless mapping.is_a?(Hash)
      raise Maxim::Error.new("status_enum called on bad params") unless mapping.keys.count == 1 && mapping.keys.first.is_a?(Symbol) && mapping.values.first.is_a?(Hash)
      raise Maxim::Error.new("status_enum called on bad params") unless mapping.values.first.to_a.map{ |a| [ a[0].class, a[1].class ] }.uniq == [ [Symbol, Integer] ]

      field = mapping.keys.first
      state_map = mapping.values.first
      reverse_map = state_map.map{|v| [v[1],v[0]]}.to_h

      define_singleton_method("#{ field.to_s.pluralize }") do
        state_map
      end

      define_method(field) do
        reverse_map[self[field]]
      end

      @transition_edges = {}
      state_map.keys.each{ |from| @transition_edges[from] = {} }

      define_method("available_#{field}_transitions") do
        self.class.instance_variable_get(:@transition_edges)[self.send(field)]
      end

      define_method("available_#{field}_transitions_from") do |to|
        self.class.instance_variable_get(:@transition_edges)[self.send(field)][to] || []
      end

      define_method("can_transition_#{field}?".to_sym) do |to:|
        self.class.instance_variable_get(:@transition_edges)[self.send(field)][to].present? && self.class.instance_variable_get(:@transition_edges)[self.send(field)][to].length > 0
      end

      state_map.each_pair do |state_name, state_value|
        scope state_name, -> { where(field => state_value) }

        define_method("#{ state_name }?".to_sym) do
          self[field] == state_value
        end
      end
    end

    def add_state_transition(field:, action:, from:, to:, in_lock_callback: nil, post_lock_callback: nil)
      raise Maxim::Error.new("method already defined") if self.instance_methods.include?(action)

      @transition_edges           ||= {}
      @transition_edges[from]     ||= {}
      @transition_edges[from][to] ||= []
      @transition_edges[from][to] << action

      define_method(action) do
        raise Maxim::InvalidTransitionError.new("Invalid state transition") if self.send(field) != from

        self.with_lock do
          self.update_column(field, self.class.send("#{ field.to_s.pluralize }").map{|v| [v[0],v[1]]}.to_h[to])

          unless in_lock_callback.nil?
            self.send(in_lock_callback, from: from, to: to)
          end
        end

        unless post_lock_callback.nil?
          self.send(post_lock_callback, from: from, to: to)
        end
      end
    end
  end
end
