# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class MetaConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :alternation
          convert_alternation
        when :dot
          context.multiline? ? '(?:.|\n)' : '.'
        else
          warn_of_unsupported_feature
        end
      end

      def convert_alternation
        alternatives = subexpressions.each_with_object([]) do |alternative, arr|
          arr << convert_expressions(alternative.expressions) if alternative
        end
        alternatives.join('|')
      end
    end
  end
end
