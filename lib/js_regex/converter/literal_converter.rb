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
            escape_literal_forward_slashes(data)
            ensure_json_compatibility(data)
            data
          end
        end

        private

        def surrogate_pair_for(astral_char)
          base = astral_char.codepoints.first - 65_536
          high = ((base / 1024).floor + 55_296).to_s(16)
          low  = (base % 1024 + 56_320).to_s(16)
          "\\u#{high}\\u#{low}"
        end

        def escape_literal_forward_slashes(data)
          # literal slashes would signify the pattern end in JsRegex#to_s
          data.gsub!('/', '\\/')
        end

        def ensure_json_compatibility(data)
          data.gsub!(/\\?[\f\n\r\t]/) { |lit| Regexp.escape(lit.delete('\\')) }
        end
      end

      private

      def convert_data
        self.class.convert_data(data)
      end
    end
  end
end
