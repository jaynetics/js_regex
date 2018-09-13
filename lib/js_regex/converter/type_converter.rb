# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class TypeConverter < JsRegex::Converter::Base
      TYPES_SHARED_BY_RUBY_AND_JS = %i[
        digit
        nondigit
        word
        nonword
        space
        nonspace
      ].freeze

      HEX_EXPANSION       = '[0-9A-Fa-f]'
      NONHEX_EXPANSION    = '[^0-9A-Fa-f]'
      LINEBREAK_EXPANSION = '(?:\r\n|\r|\n)'

      private

      def convert_data
        case subtype
        when :hex then HEX_EXPANSION
        when :nonhex then NONHEX_EXPANSION
        when :linebreak then LINEBREAK_EXPANSION
        when *TYPES_SHARED_BY_RUBY_AND_JS
          pass_through
        else
          warn_of_unsupported_feature
        end
      end
    end
  end
end
