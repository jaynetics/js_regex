# frozen_string_literal: true

require_relative 'base'
require_relative 'property_converter'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    # Note the inheritance from PropertyConverter.
    #
    class NonpropertyConverter < JsRegex::Converter::PropertyConverter
      private

      def convert_data
        if context.set?
          context.buffered_set_extractions << convert_property(true)
          ''
        else
          convert_property(true)
        end
      end
    end
  end
end
