# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class TypeConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :hex then hex_expansion
        when :nonhex then nonhex_expansion
        when :linebreak then linebreak_expansion
        when :xgrapheme then xgrapheme
        when :digit, :space, :word
          return pass_through if Utils::CharTypes.directly_compatible?(expression)

          set_substitution
        when :nondigit, :nonspace, :nonword
          return pass_through if Utils::CharTypes.directly_compatible?(expression)

          negative_set_substitution
        else
          warn_of_unsupported_feature
        end
      end

      def hex_expansion
        if context.es_2018_or_higher? && context.enable_u_option
          ES2018_HEX_EXPANSION
        elsif context.case_insensitive_root
          I_MODE_HEX_EXPANSION
        else
          HEX_EXPANSION
        end
      end

      ES2018_HEX_EXPANSION = '\p{AHex}'
      I_MODE_HEX_EXPANSION = '[0-9A-F]'
      HEX_EXPANSION        = '[0-9A-Fa-f]'

      def nonhex_expansion
        if context.es_2018_or_higher? && context.enable_u_option
          ES2018_NONHEX_EXPANSION
        elsif context.case_insensitive_root
          I_MODE_NONHEX_EXPANSION
        else
          NONHEX_EXPANSION
        end
      end

      NONHEX_EXPANSION        = '[^0-9A-Fa-f]'
      I_MODE_NONHEX_EXPANSION = '[^0-9A-F]'
      ES2018_NONHEX_EXPANSION = '\P{AHex}'

      def linebreak_expansion
        wrap_in_backrefed_lookahead(LINEBREAK_EXPANSION)
      end

      LINEBREAK_EXPANSION = '(?:\r\n|[\n\v\f\r\u0085\u2028\u2029])'

      def negative_set_substitution
        # ::of_expression returns an inverted set for negative expressions,
        # so we need to un-invert before wrapping in [^ and ]. Kinda lame.
        "[^#{character_set.inversion.bmp_part}]"
      end

      def set_substitution
        character_set.bmp_part.to_s(in_brackets: true)
      end

      def character_set
        CharacterSet.of_expression(expression)
      end

      def xgrapheme
        if context.es_2018_or_higher? && context.enable_u_option
          wrap_in_backrefed_lookahead(ES2018_XGRAPHEME_EXPANSION)
        else
          warn_of_unsupported_feature
        end
      end

      # partially taken from https://unicode.org/reports/tr51/#EBNF_and_Regex
      ES2018_XGRAPHEME_EXPANSION = <<-'REGEXP'.gsub(/\s+/, '')
        (?:
          \r\n
        |
          \p{RI}\p{RI}
        |
          \p{Emoji}
          (?:
            \p{EMod}
          |
            \uFE0F\u20E3?
          |
            [\u{E0020}-\u{E007E}]+\u{E007F}
          )?
          (?:
            \u200D
            (?:
              \p{RI}\p{RI}
            |
              \p{Emoji}(?:\p{EMod}|\uFE0F\u20E3?|[\u{E0020}-\u{E007E}]+\u{E007F})?
            )
          )*
        |
          [\P{M}\P{Lm}](?:\u200d|\p{M}|\p{Lm}|\p{Emoji_Modifier})*
        )
      REGEXP
    end
  end
end
