# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class QuantifierConverter < JsRegex::Converter::Base
      private

      def convert_data
        if context.stacked_quantifier?(start_index, end_index)
          warn_of_unsupported_feature('adjacent quantifiers')
        else
          convert_quantifier
        end
      end

      def convert_quantifier
        if data.length > 1 && data.end_with?('+')
          warn_of_unsupported_feature('declaration of quantifier as possessive')
          data[0..-2]
        else
          pass_through
        end
      end
    end
  end
end
