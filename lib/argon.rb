# frozen_string_literal: true

require 'argon/version'
require 'argon/error'
require 'argon/invalid_transition_error'
require 'argon/invalid_parameter_error'
require 'active_support/concern'
require 'active_support/inflector'
require 'symbolic_enum'
require 'pry-byebug'

module Argon
  extend ActiveSupport::Concern
  extend ActiveSupport::Inflector
  include ActiveSupport::Inflector
  include SymbolicEnum

  module ClassMethods
    def state_machine(mapping)
      raise Argon::Error.new('state_machine() has to be called on a Hash') unless mapping.is_a?(Hash)
      raise Argon::Error.new('state_machine() has to specify a field and the mappings') unless mapping.keys.count == 1 && mapping.keys.first.is_a?(Symbol) && mapping.values.first.is_a?(Hash)
      raise Argon::Error.new('state_machine() should have (only) the following mappings: states, events, edges, parameters (optional), on_successful_transition, on_failed_transition') unless mapping.values.first.keys.to_set.subset?(%i(states events edges on_successful_transition on_failed_transition parameters).to_set) && %i(states events edges on_successful_transition on_failed_transition).to_set.subset?(mapping.values.first.keys.to_set)

      field                    = mapping.keys.first
      states_map               = mapping.values.first[:states]
      events_list              = mapping.values.first[:events]
      parameters               = mapping.values.first[:parameters]
      edges_list               = mapping.values.first[:edges]
      on_successful_transition = mapping.values.first[:on_successful_transition]
      on_failed_transition     = mapping.values.first[:on_failed_transition]

      raise Argon::Error.new('`states` should be a Hash') unless states_map.is_a?(Hash)
      raise Argon::Error.new('`states` does not specify any states') if states_map.empty?
      raise Argon::Error.new('`states` must be a mapping of Symbols to unique Integers') unless states_map.keys.map(&:class).uniq == [Symbol] && states_map.values.map(&:class).uniq == [Integer] && states_map.values.uniq.sort == states_map.values.sort

      states_map.keys.each do |state_name|
        raise Argon::Error.new("`#{state_name}` is an invalid state name. `#{self.name}.#{state_name}` method already exists") if self.singleton_methods.include?(state_name)
        raise Argon::Error.new("`#{state_name}` is an invalid state name. `#{self.name}##{state_name}?` method already exists") if self.instance_methods.include?("#{state_name}?".to_sym)
      end

      raise Argon::Error.new('`events` should be an Array of Symbols') if !events_list.is_a?(Array) || (events_list.length > 0 && events_list.map(&:class).uniq != [Symbol])

      events_list.each do |event_name|
        raise Argon::Error.new("`#{event_name}` is not a valid event name. `#{self.name}##{event_name}` method already exists") if self.instance_methods.include?(event_name)

        event_edges = edges_list.select { |e| !e[:on_events].nil? && e[:on_events].include?(event_name) }

        if event_edges.empty?
          raise Argon::Error.new("`on_#{event_name}(action:)` not found") if !self.instance_methods.include?("on_#{event_name}".to_sym) || self.instance_method("on_#{event_name}".to_sym).parameters.to_set != [[:keyreq, :action]].to_set
          raise Argon::Error.new("`after_#{event_name}(action:)` not found") if !self.instance_methods.include?("after_#{event_name}".to_sym) || self.instance_method("after_#{event_name}".to_sym).parameters.to_set != [[:keyreq, :action]].to_set
        else
          raise Argon::Error.new("Event `#{event_name}` is being used by edges (#{event_edges.map { |e| "`#{e[:action]}`" }.join(", ")}) with mixed lists of parameters") if event_edges.map { |e| (e[:parameters] || []).to_set }.uniq.length > 1

          expected_parameters = %i(action)
          if !event_edges[0][:parameters].nil?
            expected_parameters += parameters.values_at(*event_edges[0][:parameters]).map { |p| p[:name] }
          end
          raise Argon::Error.new("`on_#{event_name}(#{expected_parameters.map { |p| "#{p}:" }.join(", ")})` not found") if !self.instance_methods.include?("on_#{event_name}".to_sym) || self.instance_method("on_#{event_name}".to_sym).parameters.to_set != expected_parameters.map { |name| [:keyreq, name] }.to_set
          raise Argon::Error.new("`after_#{event_name}(#{expected_parameters.map { |p| "#{p}:" }.join(", ")})` not found") if !self.instance_methods.include?("after_#{event_name}".to_sym) || self.instance_method("after_#{event_name}".to_sym).parameters.to_set != expected_parameters.map { |name| [:keyreq, name] }.to_set
        end
      end
      raise Argon::Error.new('`parameters` should be a Hash with keys as the parameter identifier, with value as a Hash as {name: Symbol, check: lambda(object)}') if !parameters.nil? && !parameters.is_a?(Hash) && parameters.keys.map(&:class).to_set != [Symbol].to_set

      if !parameters.nil?
        parameters.each_pair do |param_name, param_details|
          raise Argon::Error.new("`parameters.#{param_name}` should be a Hash with keys as the parameter identifier, with value as a Hash as {name: Symbol, check: lambda(object)}") if param_details.keys.to_set != %i(name check).to_set
          raise Argon::Error.new("`parameters.#{param_name}.name` should be a Symbol") unless param_details[:name].is_a?(Symbol)
          raise Argon::Error.new("`parameters.#{param_name}.check` should be a lambda that takes one arg") if !param_details[:check].is_a?(Proc) || !(param_details[:check].parameters.length == 1 && param_details[:check].parameters[0].length == 2 && param_details[:check].parameters[0][0] == :req && param_details[:check].parameters[0][1].is_a?(Symbol))
        end
      end

      raise Argon::Error.new('`edges` should be an Array of Hashes, with keys: from, to, action, callbacks{on: true/false, after: true/false}, on_events (optional), parameters (optional)') if !edges_list.is_a?(Array) || edges_list.map(&:class).to_set != [Hash].to_set

      edges_list.each_with_index do |edge_details, index|
        from                   = edge_details[:from]
        to                     = edge_details[:to]
        action                 = edge_details[:action]
        do_action              = "#{action}!".to_sym
        check_action           = "can_#{action}?".to_sym
        action_parameters      = edge_details[:parameters]
        action_parameter_names = (action_parameters.nil? || parameters.nil?) ? [] : parameters.values_at(*action_parameters).compact.map { |p| p[:name] }

        raise Argon::Error.new('`edges` should be an Array of Hashes, with keys: from, to, action, callbacks{on: true/false, after: true/false}, on_events (optional), parameters (optional)') unless edge_details.keys.to_set.subset?([:from, :to, :action, :callbacks, :on_events, :parameters].to_set) && [:from, :to, :action, :callbacks].to_set.subset?(edge_details.keys.to_set)
        raise Argon::Error.new("`edges[#{index}].from` is not a valid state") unless states_map.keys.include?(from)
        raise Argon::Error.new("`edges[#{index}].to` is not a valid state") unless states_map.keys.include?(to)
        raise Argon::Error.new("`edges[#{index}].action` is not a Symbol") unless action.is_a?(Symbol)
        raise Argon::Error.new("`#{edge_details[:action]}` is an invalid action name. `#{self.name}##{do_action}` method already exists") if self.instance_methods.include?(do_action)
        raise Argon::Error.new("`#{edge_details[:action]}` is an invalid action name. `#{self.name}##{check_action}` method already exists") if self.instance_methods.include?(check_action)
        raise Argon::Error.new("`edges[#{index}].callbacks` must be {on: true/false, after: true/false}") if !edge_details[:callbacks].is_a?(Hash) || edge_details[:callbacks].keys.to_set != [:after, :on].to_set || !edge_details[:callbacks].values.to_set.subset?([true, false].to_set)

        if edge_details[:callbacks][:on]
          raise Argon::Error.new("`on_#{edge_details[:action]}(#{action_parameter_names.map { |p| "#{p}:" }.join(", ")})` not found") if !self.instance_methods.include?("on_#{edge_details[:action]}".to_sym) || self.instance_method("on_#{edge_details[:action]}".to_sym).parameters.to_set != action_parameter_names.map { |name| [:keyreq, name] }.to_set
        end
        if edge_details[:callbacks][:after]
          raise Argon::Error.new("`after_#{edge_details[:action]}(#{action_parameter_names.map { |p| "#{p}:" }.join(",")})` not found") if !self.instance_methods.include?("after_#{edge_details[:action]}".to_sym) || self.instance_method("after_#{edge_details[:action]}".to_sym).parameters.to_set != action_parameter_names.map { |name| [:keyreq, name] }.to_set
        end
        raise Argon::Error.new("`#{edge_details[:on_events]}` (`edges[#{index}].on_events`) is not a valid list of events") if !edge_details[:on_events].nil? && !edge_details[:on_events].is_a?(Array)

        unless edge_details[:on_events].nil?
          edge_details[:on_events].each_with_index do |event_name, event_index|
            raise Argon::Error.new("`#{event_name}` (`edges[#{index}].on_events[#{event_index}]`) is not a registered event") unless events_list.include?(event_name)
          end
        end

        raise Argon::Error.new("`edges[#{index}].parameters` lists multiple parameters with the same name") if action_parameter_names.length != action_parameter_names.uniq.length

        unless edge_details[:parameters].nil?
          edge_details[:parameters].each_with_index do |param_name, param_index|
            raise Argon::Error.new("`#{param_name}` (`edges[#{index}].parameters[#{param_index}]`) is not a registered parameter") unless parameters.keys.include?(param_name)
          end
        end
      end

      raise Argon::Error.new('`on_successful_transition` must be a boolean') unless [true, false].include?(on_successful_transition)
      raise Argon::Error.new('`on_successful_transition` must be a method of signature `(field:, action:, from:, to:)`') if on_successful_transition && !self.instance_methods.include?(:on_successful_transition)
      raise Argon::Error.new('`on_successful_transition` must be a method of signature `(field:, action:, from:, to:)`') if on_successful_transition && self.instance_method(:on_successful_transition).parameters.to_set != %i(field action from to).map { |f| [:keyreq, f] }.to_set

      raise Argon::Error.new('`on_failed_transition` must be a boolean') unless [true, false].include?(on_failed_transition)
      raise Argon::Error.new('`on_failed_transition` must be a method of signature `(field:, action:, from:, to:)`') if on_failed_transition && !self.instance_methods.include?(:on_failed_transition)
      raise Argon::Error.new('`on_failed_transition` must be a method of signature `(field:, action:, from:, to:)`') if on_failed_transition && self.instance_method(:on_failed_transition).parameters.to_set != %i(field action from to).map { |f| [:keyreq, f] }.to_set

      events_list.each do |event_name|
      end

      state_machines = {}
      begin
        state_machines = self.class_variable_get(:@@state_machines)
      rescue NameError
      end
      state_machines ||= {}
      state_machines = state_machines.merge(mapping)
      self.class_variable_set(:@@state_machines, state_machines)

      class << self
        attr_accessor :state_machines
      end

      define_singleton_method(:state_machines) do
        self.class_variable_get(:@@state_machines || {})
      end

      symbolic_enum field => states_map, disable_setters: true

      edges_list.each do |edge_details|
        from               = edge_details[:from]
        to                 = edge_details[:to]
        action             = edge_details[:action]
        action_parameters  = edge_details[:parameters] || []
        on_lock_callback   = "on_#{action}".to_sym if edge_details[:callbacks][:on] == true
        after_lock_callback = "after_#{action}".to_sym if edge_details[:callbacks][:after] == true

        define_method("can_#{action}?".to_sym) do
          self.send(field) == from
        end

        define_method("#{action}!".to_sym) do |**args, &block|
          required_keywords = !parameters.nil? ? parameters.values_at(*action_parameters).map { |p| p[:name] } : []
          available_keywords = args.keys

          raise ArgumentError.new('wrong number of arguments (given 1, expected 0)') if required_keywords.to_set.empty? && !available_keywords.to_set.empty?
          raise ArgumentError.new("missing #{pluralize("keyword", (required_keywords - available_keywords).length)}: #{(required_keywords - available_keywords).join(", ")}") if !required_keywords.to_set.subset?(available_keywords.to_set)
          raise ArgumentError.new("unknown #{pluralize("keyword", (available_keywords - required_keywords).length)}: #{(available_keywords - required_keywords).join(", ")}") if !available_keywords.to_set.subset?(required_keywords.to_set)

          if !parameters.nil? && !action_parameters.empty?
            parameters.select { |k, v| action_parameters.include?(k) }.each_pair do |param_name, param_details|
              raise Argon::InvalidParameterError.new("incorrect value for `#{param_details[:name]}`") if !param_details[:check].call(args[param_details[:name]])
            end
          end

          if self.send(field) != from
            if on_failed_transition
              self.on_failed_transition(field: field, action: action, from: from, to: to)
            end
            raise Argon::InvalidTransitionError.new("Invalid state transition. #{self.class.name}##{self.send(self.class.primary_key.to_sym)} cannot perform '#{action}' on #{field}='#{from}'")
          end

          begin
            self.with_lock do
              if self.send(field) != from
                raise Argon::InvalidTransitionError.new("Invalid state transition. #{self.class.name}##{self.send(self.class.primary_key.to_sym)} cannot perform '#{action}' on #{field}='#{from}'")
              end

              self.update_column(field, self.class.send("#{field.to_s.pluralize}").map { |v| [v[0], v[1]] }.to_h[to])
              self.touch

              unless on_lock_callback.nil?
                if args.empty?
                  self.send(on_lock_callback)
                else
                  self.send(on_lock_callback, args)
                end
              end

              unless block.nil?
                block.call
              end
            end
          rescue => e
            if on_failed_transition
              self.on_failed_transition(field: field, action: action, from: from, to: to)
            end
            raise e
          end

          if on_successful_transition
            self.on_successful_transition(field: field, action: action, from: from, to: to)
          end

          unless after_lock_callback.nil?
            if args.empty?
              self.send(after_lock_callback)
            else
              self.send(after_lock_callback, args)
            end
          end
        end
      end

      events_list.each do |event_name|
        define_method("#{event_name}!".to_sym) do |**args|
          matching_edges = edges_list.select { |edge| !edge[:on_events].nil? && edge[:on_events].to_set.include?(event_name) }

          matching_edges.each do |edge|
            action = edge[:action]

            if self.send("can_#{action}?")
              if args.empty?
                self.send("#{action}!") do
                  self.send("on_#{event_name}", { action: action })
                end
              else
                self.send("#{action}!", args) do
                  self.send("on_#{event_name}", { action: action }.merge(args))
                end
              end
              self.send("after_#{event_name}", { action: action }.merge(args))
              return
            end
          end

          raise Argon::InvalidTransitionError.new("No valid transitions for #{self.class.name}##{self.send(self.class.primary_key.to_sym)}##{field}")
        end
      end
    end
  end
end
