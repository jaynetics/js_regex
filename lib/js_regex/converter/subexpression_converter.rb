require_relative 'base'

module LangRegex
  module Converter
    #
    # Template class implementation.
    #
    class SubexpressionConverter < Base
      private

      def convert_data
        convert_subexpressions
      end
    end
  end
end
