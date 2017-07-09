require 'maxim/version'
require 'maxim/error'
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

      state_map.each_pair do |state_name, state_value|
        scope state_name, -> { where("#{field} = ?", state_value) }

        define_method("#{ state_name }?".to_sym) do
          self[field] == state_value
        end
      end
    end

    def add_state_transition(name, edge, *options)
      @state_transitions[name] = {
        edge: edge,
        options: options
      }
    end
  end
end
