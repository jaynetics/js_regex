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
        warn_of_unsupported_feature('conditional')
        options = subexpressions[1..-1].each_with_object([]) do |option, arr|
          arr << convert_expressions(option.expressions) if option
        end
        "(?:#{options.join('|')})"
      end
    end
  end
end
