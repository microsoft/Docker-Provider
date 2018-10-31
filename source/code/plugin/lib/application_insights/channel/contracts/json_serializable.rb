require 'json'

module ApplicationInsights
  module Channel
    module Contracts
      module JsonSerializable
        module ClassMethods
          attr_reader :json_mappings

          def attribute_mapping(mappings = {})
            @json_mappings = mappings
          end
        end

        def self.included(klass)
          klass.extend JsonSerializable::ClassMethods
        end

        def initialize(attributes = {})
          attributes.each { |k, v| send(:"#{k}=", v) }
        end

        def to_h
          output = {}
          klass = self.class

          klass.json_mappings.each do |attr, name|
            value = visit self.send(attr)
            is_empty = value.respond_to?(:empty?) && value.empty?

            output[name] = value unless value.nil? || is_empty
          end

          output
        end

        def to_json(args = {})
          JSON.generate self.to_h, args
        end

        private

        def visit(object)
          return if object.nil?

          if object.is_a? Array
            object.map { |e| visit e }
          elsif object.is_a? Hash
            Hash[object.map { |k, v| [k, visit(v)] }]
          elsif object.respond_to? :to_h
            object.to_h
          else
            object
          end
        end
      end
    end
  end
end
