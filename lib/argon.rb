require 'argon/version'
require 'argon/error'
require 'argon/invalid_transition_error'
require 'active_support/concern'
require 'active_support/inflector'
require 'pry-byebug'

module Argon
  extend ActiveSupport::Concern

  module ClassMethods
    def state_machine(mapping)
      raise Argon::Error.new("state_machine() has to be called on a Hash") unless mapping.is_a?(Hash)
      raise Argon::Error.new("state_machine() has to specify a field and the mappings") unless mapping.keys.count == 1 && mapping.keys.first.is_a?(Symbol) && mapping.values.first.is_a?(Hash)
      raise Argon::Error.new("state_machine() should have (only) the following mappings: states, events, edges, on_successful_transition, on_failed_transition") if mapping.values.first.keys.sort != %i(states events edges on_successful_transition on_failed_transition).sort

      field                    = mapping.keys.first
      states_map               = mapping.values.first[:states]
      events_list              = mapping.values.first[:events]
      edges_list               = mapping.values.first[:edges]
      on_successful_transition = mapping.values.first[:on_successful_transition]
      on_failed_transition     = mapping.values.first[:on_failed_transition]

      raise Argon::Error.new("`states` should be a Hash") unless states_map.is_a?(Hash)
      raise Argon::Error.new("`states` does not specify any states") if states_map.empty?
      raise Argon::Error.new("`states` must be a mapping of Symbols to unique Integers") unless states_map.keys.map(&:class).uniq == [Symbol] && states_map.values.map(&:class).uniq == [Integer] && states_map.values.uniq.sort == states_map.values.sort
      states_map.keys.each do |state_name|
        raise Argon::Error.new("`#{state_name}` is an invalid state name. `#{self.name}.#{state_name}` method already exists") if self.singleton_methods.include?(state_name)
        raise Argon::Error.new("`#{state_name}` is an invalid state name. `#{self.name}##{state_name}?` method already exists") if self.instance_methods.include?("#{state_name}?".to_sym)
      end

      raise Argon::Error.new("`events` should be an Array of Symbols") if !events_list.is_a?(Array) || (events_list.length > 0 && events_list.map(&:class).uniq != [Symbol])
      events_list.each do |event_name|
        raise Argon::Error.new("`#{event_name}` is not a valid event name. `#{self.name}##{event_name}` method already exists") if self.instance_methods.include?(event_name)
        raise Argon::Error.new("`on_#{event_name}()` not found") if !self.instance_methods.include?("on_#{event_name}".to_sym) || self.instance_method("on_#{event_name}".to_sym).parameters.to_set != [].to_set
        raise Argon::Error.new("`after_#{event_name}()` not found") if !self.instance_methods.include?("after_#{event_name}".to_sym) || self.instance_method("after_#{event_name}".to_sym).parameters.to_set != [].to_set
      end

      raise Argon::Error.new("`edges` should be an Array of Hashes, with keys: from, to, action, callbacks{on: true/false, after: true/false}, on_events (optional)") if !edges_list.is_a?(Array) || edges_list.map(&:class).uniq != [Hash]

      registered_edge_pairs = [].to_set
      edges_list.each_with_index do |edge_details, index|
        from         = edge_details[:from]
        to           = edge_details[:to]
        action       = edge_details[:action]
        do_action    = "#{action}!".to_sym
        check_action = "can_#{action}?".to_sym

        raise Argon::Error.new("`edges` should be an Array of Hashes, with keys: from, to, action, callbacks{on: true/false, after: true/false}, on_events (optional)") unless edge_details.keys.to_set.subset?([:from, :to, :action, :callbacks, :on_events].to_set) && [:from, :to, :action, :callbacks].to_set.subset?(edge_details.keys.to_set)
        raise Argon::Error.new("`edges[#{index}].from` is not a valid state") unless states_map.keys.include?(from)
        raise Argon::Error.new("`edges[#{index}].to` is not a valid state") unless states_map.keys.include?(to)
        raise Argon::Error.new("`edges[#{index}].action` is not a Symbol") unless action.is_a?(Symbol)
        raise Argon::Error.new("`#{edge_details[:action]}` is an invalid action name. `#{self.name}##{do_action}` method already exists") if self.instance_methods.include?(do_action)
        raise Argon::Error.new("`#{edge_details[:action]}` is an invalid action name. `#{self.name}##{check_action}` method already exists") if self.instance_methods.include?(check_action)
        raise Argon::Error.new("`edges[#{index}].callbacks` must be {on: true/false, after: true/false}") if !edge_details[:callbacks].is_a?(Hash) || edge_details[:callbacks].keys.to_set != [:after, :on].to_set || !edge_details[:callbacks].values.to_set.subset?([true, false].to_set)
        if edge_details[:callbacks][:on]
          raise Argon::Error.new("`on_#{edge_details[:action]}()` not found") if !self.instance_methods.include?("on_#{edge_details[:action]}".to_sym) || self.instance_method("on_#{edge_details[:action]}".to_sym).parameters.to_set != [].to_set
        end
        if edge_details[:callbacks][:after]
          raise Argon::Error.new("`after_#{edge_details[:action]}()` not found") if !self.instance_methods.include?("after_#{edge_details[:action]}".to_sym) || self.instance_method("after_#{edge_details[:action]}".to_sym).parameters.to_set != [].to_set
        end
        raise Argon::Error.new("`#{edge_details[:on_events]}` (`edges[#{index}].on_events`) is not a valid list of events") if !edge_details[:on_events].nil? && !edge_details[:on_events].is_a?(Array)
        unless edge_details[:on_events].nil?
          edge_details[:on_events].each_with_index do |event_name, event_index|
            raise Argon::Error.new("`#{ event_name }` (`edges[#{index}].on_events[#{event_index}]`) is not a registered event") unless events_list.include?(event_name)
          end
        end
        raise Argon::Error.new("`edges[#{index}]` is a duplicate edge") if registered_edge_pairs.include?([from,to])
        registered_edge_pairs << [from, to]
      end

      raise Argon::Error.new("`on_successful_transition` must be a lambda of signature `(from:, to:)`") if !on_successful_transition.nil? && !on_successful_transition.is_a?(Proc)
      raise Argon::Error.new("`on_successful_transition` must be a lambda of signature `(from:, to:)`") if on_successful_transition.parameters.to_set != [[:keyreq, :from],[:keyreq, :to]].to_set

      raise Argon::Error.new("`on_failed_transition` must be a lambda of signature `(from:, to:)`") if !on_failed_transition.nil? && !on_failed_transition.is_a?(Proc)
      raise Argon::Error.new("`on_failed_transition` must be a lambda of signature `(from:, to:)`") if on_failed_transition.parameters.to_set != [[:keyreq, :from],[:keyreq, :to]].to_set

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

      # Replicating enum functionality (partially)
      define_singleton_method("#{ field.to_s.pluralize }") do
        states_map
      end

      reverse_states_map = states_map.map{|v| [v[1],v[0]]}.to_h

      define_method(field) do
        reverse_states_map[self[field]]
      end

      states_map.each_pair do |state_name, state_value|
        scope state_name, -> { where(field => state_value) }

        define_method("#{ state_name }?".to_sym) do
          self[field] == state_value
        end
      end

      edges_list.each do |edge_details|
        from               = edge_details[:from]
        to                 = edge_details[:to]
        action             = edge_details[:action]
        on_lock_callback   = "on_#{action}".to_sym if edge_details[:callbacks][:on] == true
        after_lock_callback = "after_#{action}".to_sym if edge_details[:callbacks][:after] == true

        define_method("can_#{action}?".to_sym) do
          self.send(field) == from
        end

        define_method("#{action}!".to_sym) do |&block|
          if self.send(field) != from
            on_failed_transition.call(from: self.send(field), to: to)
            raise Argon::InvalidTransitionError.new("Invalid state transition")
          end

          begin
            self.with_lock do
              self.update_column(field, self.class.send("#{ field.to_s.pluralize }").map{|v| [v[0],v[1]]}.to_h[to])
              self.touch

              unless on_lock_callback.nil?
                self.send(on_lock_callback)
              end

              unless block.nil?
                block.call
              end
            end
          rescue => e
            on_failed_transition.call(from: self.send(field), to: to)
            raise e
          end

          on_successful_transition.call(from: from, to: to)

          unless after_lock_callback.nil?
            self.send(after_lock_callback)
          end
        end
      end

      events_list.each do |event_name|
        define_method("#{event_name}!".to_sym) do
          matching_edges = edges_list.select{ |edge| !edge[:on_events].nil? && edge[:on_events].to_set.include?(event_name) }

          matching_edges.each do |edge|
            action = edge[:action]

            if self.send("can_#{ action }?")
              self.send("#{ action }!") do
                self.send("on_#{ event_name }")
              end
              self.send("after_#{ event_name }")
              return
            end
          end

          raise Argon::InvalidTransitionError.new("No valid transitions")
        end
      end
    end
  end
end
