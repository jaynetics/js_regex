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
        branches = subexpressions.drop(1).each_with_object([]) do |branch, arr|
          converted_branch = convert_expressions(branch)
          arr << converted_branch unless converted_branch.eql?('')
        end
        "(?:#{branches.join('|')})"
      end
    end
  end
end
