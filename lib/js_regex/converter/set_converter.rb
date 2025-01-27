require_relative 'base'
require_relative 'escape_converter'
require_relative 'type_converter'
require 'character_set'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    # Unlike other converters, this one does not recurse on subexpressions,
    # since many are unsupported by JavaScript. If it detects incompatible
    # children, it uses the `character_set` gem to establish the codepoints
    # matched by the whole set and build a completely new set string.
    #
    class SetConverter < JsRegex::Converter::Base
      private

      def convert_data
        simple_conversion || full_recalculation
      end

      def simple_conversion
        return false if casefolding_needed?

        result = "[#{'^' if expression.negative?}".dup

        expression.expressions.each do |subexp|
          return false unless (child_res = simple_convert_child(subexp))

          result << child_res.to_s
        end

        result << ']'
      end

      def casefolding_needed?
        expression.case_insensitive? ^ context.case_insensitive_root
      end

      def simple_convert_child(exp)
        case exp.type
        when :literal
          simple_convert_literal_child(exp)
        when :set
          # full conversion is needed for nested sets and intersections
          exp.token.equal?(:range) && exp.expressions.map do |op|
            simple_convert_child(op) or return false
          end.join('-')
        when :type
          TypeConverter.directly_compatible?(exp, context) &&
            exp.text
        when :escape
          return exp.text if SET_SPECIFIC_ESCAPES_PATTERN.match?(exp.text)

          case exp.token
          when *CONVERTIBLE_ESCAPE_TOKENS
            EscapeConverter.new.convert(exp, context)
          when :literal
            exp.char.ord <= 0xFFFF &&
              LiteralConverter.escape_incompatible_bmp_literals(exp.char)
          end
        end
      end

      def simple_convert_literal_child(exp)
        if !context.u? &&
           exp.text =~ LiteralConverter::ASTRAL_PLANE_CODEPOINT_PATTERN &&
           !context.enable_u_option
          false
        elsif SET_LITERALS_REQUIRING_ESCAPE_PATTERN.match?(exp.text)
          "\\#{exp.text}"
        else
          LiteralConverter.escape_incompatible_bmp_literals(exp.text)
        end
      end

      SET_LITERALS_REQUIRING_ESCAPE_PATTERN = Regexp.union(%w<( ) [ ] { } / - |>)
      SET_SPECIFIC_ESCAPES_PATTERN = /[\^\-]/
      CONVERTIBLE_ESCAPE_TOKENS = %i[control meta_sequence bell escape octal] +
        EscapeConverter::ESCAPES_SHARED_BY_RUBY_AND_JS

      def full_recalculation
        # Fetch codepoints as if the set was case-sensitive, then re-add
        # case-insensitivity if needed.
        # This way we preserve the casing of the original set in cases where the
        # whole regexp is case-insensitive, e.g. /[ABc]/i => /[ABc]/i.
        content = original_case_character_set
        if expression.case_insensitive? && !context.case_insensitive_root
          content = content.case_insensitive
        elsif !expression.case_insensitive? && context.case_insensitive_root
          warn_of_unsupported_feature('nested case-sensitive set')
        end
        if context.es_2015_or_higher?
          context.enable_u_option if content.astral_part?
          content.to_s(format: 'es6', in_brackets: true)
        else
          content.to_s_with_surrogate_ranges
        end
      end

      def original_case_character_set
        neutral_set = expression.dup
        neutral_set.each_expression(true) { |exp| exp.options[:i] = false }
        CharacterSet.of_expression(neutral_set)
      end
    end
  end
end
