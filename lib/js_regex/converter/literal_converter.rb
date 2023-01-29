require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class LiteralConverter < JsRegex::Converter::Base
      ASTRAL_PLANE_CODEPOINT_PATTERN = /[\u{10000}-\u{10FFFF}]/
      LITERAL_REQUIRING_ESCAPE_PATTERN = /[\/\f\n\r\t\v]/

      class << self
        def convert_data(data, context)
          if !context.u? && data =~ ASTRAL_PLANE_CODEPOINT_PATTERN
            if context.enable_u_option
              escape_incompatible_bmp_literals(data)
            else
              convert_astral_data(data)
            end
          else
            escape_incompatible_bmp_literals(data)
          end
        end

        def convert_astral_data(data)
          data.each_char.each_with_object(Node.new) do |char, node|
            if char.ord > 0xFFFF
              node << surrogate_substitution_for(char)
            else
              node << escape_incompatible_bmp_literals(char)
            end
          end
        end

        ESCAPES = Hash.new { |h, k| raise KeyError, "#{h}[#{k.inspect}]" }
          .merge("\f\n\r\t\v".chars.to_h { |c| [c, Regexp.escape(c)] })
          .merge('/' => '\\/')

        def escape_incompatible_bmp_literals(data)
          data.gsub(LITERAL_REQUIRING_ESCAPE_PATTERN, ESCAPES)
        end

        private

        def surrogate_substitution_for(char)
          CharacterSet::Writer.write_surrogate_ranges([], [char.codepoints])
        end
      end

      private

      def convert_data
        result = self.class.convert_data(data, context)
        if context.case_insensitive_root && !expression.case_insensitive?
          warn_of_unsupported_feature('nested case-sensitive literal')
        elsif !context.case_insensitive_root && expression.case_insensitive?
          return handle_locally_case_insensitive_literal(result)
        end
        result
      end

      HAS_CASE_PATTERN = /[\p{lower}\p{upper}]/

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
