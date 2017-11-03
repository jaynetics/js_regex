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
          expression.multiline? ? '(?:.|\n)' : '.'
        else
          warn_of_unsupported_feature
        end
      end

      def convert_alternation
        branches = subexpressions.each_with_object([]) do |branch, arr|
          converted_branch = convert_expressions(branch.expressions)
          arr << converted_branch unless converted_branch.eql?('')
        end
        branches.join('|')
      end
    end
  end
end
