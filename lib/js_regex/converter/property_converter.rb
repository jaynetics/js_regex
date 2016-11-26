# frozen_string_literal: true

require_relative 'base'
require_relative File.join('..', 'property_map')

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class PropertyConverter < JsRegex::Converter::Base
      class << self
        def property_replacement(property_name, negated = nil)
          replacement = PROPERTY_MAP[property_name.downcase.to_sym]
          negated ? negated_property_replacement(replacement) : replacement
        end

        private

        def negated_property_replacement(property_string)
          return nil unless property_string
          if property_string.start_with?('[^')
            property_string.sub('[^', '[')
          else
            property_string.sub('[', '[^')
          end
        end
      end

      private

      def convert_data
        convert_property
      end

      def convert_property(negated = nil)
        replace = self.class.property_replacement(subtype, negated)
        replace || warn_of_unsupported_feature
      end
    end
  end
end
