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
        if multiplicative_interval?
          warn_of_unsupported_feature('adjacent quantifiers')
        else
          # context.previous_quantifier_type = subtype
          context.previous_quantifier_end = end_index
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

      def multiplicative_interval?
        # subtype == :interval &&
        #  context.previous_quantifier_type == :interval &&
        context.previous_quantifier_end.equal?(start_index)
      end
    end
  end
end
