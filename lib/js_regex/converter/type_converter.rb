require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class TypeConverter < JsRegex::Converter::Base
      HEX_EXPANSION              = '[0-9A-Fa-f]'
      NONHEX_EXPANSION           = '[^0-9A-Fa-f]'
      I_MODE_HEX_EXPANSION       = '[0-9A-F]'
      I_MODE_NONHEX_EXPANSION    = '[^0-9A-F]'
      ES2018_HEX_EXPANSION       = '\p{AHex}'
      ES2018_NONHEX_EXPANSION    = '\P{AHex}'
      ES2018_XGRAPHEME_EXPANSION = '[\P{M}\P{Lm}](?:(?:[\u035C\u0361]\P{M}\p{M}*)|\u200d|\p{M}|\p{Lm}|\p{Emoji_Modifier})*'
      LINEBREAK_EXPANSION        = '(?:\r\n|[\n\v\f\r\u0085\u2028\u2029])'

      def self.directly_compatible?(expression, _context = nil)
        case expression.token
        when :space, :nonspace
          !expression.ascii_classes?
        when :digit, :nondigit, :word, :nonword
          !expression.unicode_classes?
        end
      end

      private

      def convert_data
        case subtype
        when :hex then hex_expansion
        when :nonhex then nonhex_expansion
        when :linebreak then linebreak_expansion
        when :xgrapheme then xgrapheme
        when :digit, :space, :word
          return pass_through if self.class.directly_compatible?(expression)
          set_substitution
        when :nondigit, :nonspace, :nonword
          return pass_through if self.class.directly_compatible?(expression)
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

      def nonhex_expansion
        if context.es_2018_or_higher? && context.enable_u_option
          ES2018_NONHEX_EXPANSION
        elsif context.case_insensitive_root
          I_MODE_NONHEX_EXPANSION
        else
          NONHEX_EXPANSION
        end
      end

      def linebreak_expansion
        wrap_in_backrefed_lookahead(LINEBREAK_EXPANSION)
      end

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
    end
  end
end
