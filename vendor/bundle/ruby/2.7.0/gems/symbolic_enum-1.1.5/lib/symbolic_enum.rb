# frozen_string_literal: true

require 'symbolic_enum/version'
require 'active_support/concern'
require 'active_support/inflector'

module SymbolicEnum
  extend ActiveSupport::Concern

  module ClassMethods
    def symbolic_enum(params)
      raise ArgumentError.new('argument has to be a Hash of field and mapping of unique Symbols to numbers, with optional configuration params') unless params.is_a?(Hash) && params.keys.count <= 2 && params.keys.count >= 1 && params.keys.first.is_a?(Symbol) && params.values.first.is_a?(Hash)

      field = params.keys.first
      mapping = params[field]

      options = params.reject { |k, v| k == field }

      raise ArgumentError.new('argument has to be a Hash of field and mapping of unique Symbols to numbers, with optional configuration params') unless mapping.keys.count == mapping.keys.uniq.count && mapping.values.count == mapping.values.uniq.count && mapping.keys.map(&:class).uniq == [Symbol] && (mapping.values.map(&:class).uniq == [Integer] || mapping.values.map(&:class).uniq == [Fixnum])

      options.each_pair do |key, value|
        case key
        when :array
          raise ArgumentError.new("'array' option can be only true/false") unless [true, false].include?(value)
        when :disable_scopes
          raise ArgumentError.new("'disable_scopes' option can be only true/false") unless [true, false].include?(value)
        when :disable_setters
          raise ArgumentError.new("'disable_setters' option can be only true/false") unless [true, false].include?(value)
        else
          raise ArgumentError.new("'#{key}' is not a valid option")
        end
      end

      is_array = options[:array]
      disable_scopes = options[:disable_scopes]
      disable_setters = options[:disable_setters]

      mapping.keys.each do |enum_name|
        raise ArgumentError.new("'#{enum_name}' clashes with existing methods") if self.instance_methods.include?(:"#{enum_name}!") unless disable_setters
        raise ArgumentError.new("'#{enum_name}' clashes with existing methods") if self.instance_methods.include?(:"#{enum_name}?")

        raise ArgumentError.new("'#{enum_name}' clashes with existing methods") if self.singleton_methods.include?(enum_name) unless disable_scopes
      end

      symbolic_enums = {}
      begin
        symbolic_enums = self.class_variable_get(:@@symbolic_enums)
      rescue NameError
      end
      symbolic_enums ||= {}
      symbolic_enums = symbolic_enums.merge(params.select { |k, v| k == field })
      self.class_variable_set(:@@symbolic_enums, symbolic_enums)

      define_singleton_method(:symbolic_enums) do
        self.class_variable_get(:@@symbolic_enums || {})
      end

      # Replicating enum functionality (partially)
      define_singleton_method("#{field.to_s.pluralize}") do
        mapping
      end

      reverse_mapping = mapping.map { |v| [v[1], v[0]] }.to_h

      if is_array
        define_method(field) do
          return nil if self[field].nil?

          return self[field].map { |v| reverse_mapping[v] }
        end
      else
        define_method(field) do
          reverse_mapping[self[field]]
        end
      end

      mapping.each_pair do |state_name, state_value|
        unless disable_scopes
          scope state_name, -> { where(field => state_value) }
        end

        define_method("#{state_name}?".to_sym) do
          self[field] == state_value
        end

        unless disable_setters
          define_method("#{state_name}!".to_sym) do
            self.update_attributes!(field => state_value)
          end

          if is_array
            define_method("#{field}=") do |value|
              raise ArgumentError.new('can only assign a valid array of enums') unless value.nil? || (value.is_a?(Array) && value.map(&:class).to_set.subset?([String, Symbol].to_set) && value.map(&:to_sym).to_set.subset?(mapping.keys.to_set))

              self[field] = value.nil? ? nil : value.map { |s| mapping[s.to_sym] }
            end
          else
            define_method("#{field}=") do |value|
              raise ArgumentError.new('can only assign a valid enum') unless value.nil? || ((value.is_a?(Symbol) || value.is_a?(String)) && mapping.keys.include?(value.to_sym))

              self[field] = value.nil? ? nil : mapping[value.to_sym]
            end
          end
        end
      end
    end
  end
end
