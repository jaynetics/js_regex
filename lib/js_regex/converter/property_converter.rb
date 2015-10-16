class JsRegex
  #
  module Converter
    require_relative 'base'
    require_relative File.join('..', 'property_map')
    #
    # Template class implementation.
    #
    class PropertyConverter < JsRegex::Converter::Base
      def self.property_replacement(property_name, negated = false)
        replacement = JsRegex::PROPERTY_MAP[property_name.downcase.to_sym]
        negated ? negated_property_replacement(replacement) : replacement
      end

      def self.negated_property_replacement(property_string)
        # take care not to use destructive methods on elements in the map
        return nil unless property_string
        if property_string.start_with?('[^')
          property_string.sub('[^', '[')
        else
          property_string.sub('[', '[^')
        end
      end

      private

      def convert_data
        convert_property
      end

      def convert_property(negated = false)
        replace = self.class.property_replacement(subtype, negated)
        replace || warn_of_unsupported_feature
      end
    end
  end
end
