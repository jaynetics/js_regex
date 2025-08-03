# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class LiteralConverter < JsRegex::Converter::Base
      private

      def convert_data
        result = Utils::Literals.convert_data(data, context)
        if context.case_insensitive_root && !expression.case_insensitive?
          warn_of_unsupported_feature('nested case-sensitive literal')
        elsif !context.case_insensitive_root && expression.case_insensitive?
          return handle_locally_case_insensitive_literal(result)
        end
        result
      end

      HAS_CASE_PATTERN = /[\p{lower}\p{upper}]/.freeze

      def handle_locally_case_insensitive_literal(literal)
        literal =~ HAS_CASE_PATTERN ? case_insensitivize(literal) : literal
      end

      def case_insensitivize(literal)
        literal.each_char.each_with_object(Node.new) do |chr, node|
          node << (chr =~ HAS_CASE_PATTERN ? "[#{chr}#{chr.swapcase}]" : chr)
        end
      end
    end
  end
end
