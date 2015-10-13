class JsRegex
  #
  module Converter
    require_relative 'property_converter'
    #
    # Template class implementation.
    #
    # Note the inheritance from PropertyConverter.
    #
    class NonpropertyConverter < JsRegex::Converter::PropertyConverter
      private

      def convert_data
        convert_property(true)
      end
    end
  end
end
