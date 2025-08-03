# frozen_string_literal: true

require_relative '../node'
require 'character_set'

class JsRegex
  module Utils
    module Literals
      ASTRAL_PLANE_CODEPOINT_PATTERN = /[\u{10000}-\u{10FFFF}]/.freeze

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

        def escape_incompatible_bmp_literals(data)
          data.gsub(LITERAL_REQUIRING_ESCAPE_PATTERN, ESCAPES)
        end

        private

        LITERAL_REQUIRING_ESCAPE_PATTERN = /[\/\f\n\r\t\v]/.freeze

        ESCAPES = Hash.new { |h, k| raise KeyError, "#{h}[#{k.inspect}]" }
          .merge("\f\n\r\t\v".chars.to_h { |c| [c, Regexp.escape(c)] })
          .merge('/' => '\\/')

        def convert_astral_data(data)
          data.each_char.each_with_object(JsRegex::Node.new) do |char, node|
            if char.ord > 0xFFFF
              node << surrogate_substitution_for(char)
            else
              node << escape_incompatible_bmp_literals(char)
            end
          end
        end

        def surrogate_substitution_for(char)
          CharacterSet::Writer.write_surrogate_ranges([], [char.codepoints])
        end
      end
    end
  end
end
