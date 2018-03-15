# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class LiteralConverter < JsRegex::Converter::Base
      class << self
        ASTRAL_PLANE_CODEPOINT_PATTERN = /\A[\u{10000}-\u{FFFFF}]\z/

        def convert_data(data)
          if data =~ ASTRAL_PLANE_CODEPOINT_PATTERN
            surrogate_pair_for(data)
          else
            ensure_json_compatibility(
              ensure_forward_slashes_are_escaped(data)
            )
          end
        end

        private

        def surrogate_pair_for(astral_char)
          base = astral_char.codepoints.first - 65_536
          high = ((base / 1024).floor + 55_296).to_s(16)
          low  = (base % 1024 + 56_320).to_s(16)
          "(?:\\u#{high}\\u#{low})"
        end

        def ensure_forward_slashes_are_escaped(data)
          # literal slashes would signify the pattern end in JsRegex#to_s
          data.gsub(%r{\\?/}, '\\/')
        end

        def ensure_json_compatibility(data)
          data.gsub(%r{\\?([\f\n\r\t])}) { Regexp.escape($1) }
        end
      end

      private

      def convert_data
        result = self.class.convert_data(data)
        if context.case_insensitive_root && !expression.case_insensitive?
          warn_of_unsupported_feature('nested case-sensitive literal')
        elsif !context.case_insensitive_root && expression.case_insensitive?
          return handle_locally_case_insensitive_literal(result)
        end
        result
      end

      HAS_CASE_PATTERN = /[\p{lower}\p{upper}]/

      def handle_locally_case_insensitive_literal(literal)
        return literal unless literal =~ HAS_CASE_PATTERN
        "[#{literal}#{literal.swapcase}]"
      end
    end
  end
end
