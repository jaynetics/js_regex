# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class TypeConverter < JsRegex::Converter::Base
      HEX_EXPANSION       = '[A-Fa-f0-9]'
      NONHEX_EXPANSION    = '[^A-Fa-f0-9]'
      LINEBREAK_EXPANSION = '(\r\n|\r|\n)'

      private

      def convert_data
        case subtype
        when :hex then HEX_EXPANSION
        when :nonhex then NONHEX_EXPANSION
        when :linebreak then LINEBREAK_EXPANSION
        when :digit, :nondigit, :word, :nonword, :space, :nonspace
          pass_through
        else
          warn_of_unsupported_feature
        end
      end
    end
  end
end
