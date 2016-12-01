# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class ConditionalConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :open
          warn_of_unsupported_feature('conditional')
          '('
        when :separator, :close
          pass_through
        else
          '' # one warning is enough, don't warn about other parts
        end
      end
    end
  end
end
