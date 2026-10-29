# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    # Uses the `character_set` and `regexp_property_values` gems to get the
    # codepoints matched by the property and build a set string from them.
    #
    class PropertyConverter < JsRegex::Converter::Base
      private

      def convert_data
        if context.es_2018_or_higher? &&
            (prop_name_in_js = Utils::Properties.name_in_js(subtype))
          context.enable_u_option
          "\\#{expression.negative? ? 'P' : 'p'}{#{prop_name_in_js}}"
        else
          Utils::CharSets.convert(expression, context)
        end
      end
    end
  end
end
