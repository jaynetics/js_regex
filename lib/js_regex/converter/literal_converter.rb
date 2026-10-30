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
          return handle_locally_case_insensitive_literal(data)
        end
        result
      end

      HAS_CASE_PATTERN = /[\p{lower}\p{upper}]/.freeze

      def handle_locally_case_insensitive_literal(literal)
        literal.match?(HAS_CASE_PATTERN) ? case_insensitivize(literal) : Utils::Literals.convert_data(literal, context)
      end

      def case_insensitivize(literal)
        literal.each_char.each_with_object(Node.new) do |chr, node|
          if chr.match?(HAS_CASE_PATTERN)
            if chr.ord > 0xFFFF && !context.enable_u_option
              node << Node.new('(?:', Utils::Literals.convert_data(chr, context), '|',
                               Utils::Literals.convert_data(chr.swapcase, context), ')')
            else
              node << "[#{chr}#{chr.swapcase}]"
            end
          else
            node << Utils::Literals.convert_data(chr, context)
          end
        end
      end
    end
  end
end
