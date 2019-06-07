# frozen_string_literal: true

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
      private

      def convert_data
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
