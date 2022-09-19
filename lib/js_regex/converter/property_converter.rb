require_relative 'base'
require 'character_set'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    # Uses the `character_set` and `regexp_property_values` gems to get the
    # codepoints matched by the property and build a set string from them.
    #
    class PropertyConverter < JsRegex::Converter::Base
      # A map of normalized Ruby property names to names supported by ES2018+.
      def self.map
        @map ||= File.read("#{__dir__}/property_map.csv").scan(/(.+),(.+)/).to_h
      end

      private

      def convert_data
        if context.es_2018_or_higher? &&
            (prop_name_in_js = self.class.map[subtype.to_s.tr('_', '')])
          context.enable_u_option
          "\\#{expression.negative? ? 'P' : 'p'}{#{prop_name_in_js}}"
        else
          build_character_set
        end
      end

      def build_character_set
        content = CharacterSet.of_expression(expression)

        if expression.case_insensitive? && !context.case_insensitive_root
          content = content.case_insensitive
        elsif !expression.case_insensitive? && context.case_insensitive_root
          warn_of_unsupported_feature('nested case-sensitive property')
        end

        content.to_s_with_surrogate_ranges
      end
    end
  end
end
