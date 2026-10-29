# frozen_string_literal: true

require_relative 'base'

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
        simple_conversion || Utils::CharSets.convert(expression, context)
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
          Utils::CharTypes.directly_compatible?(exp) && exp.text
        when :escape
          return exp.text if SET_SPECIFIC_ESCAPES_PATTERN.match?(exp.text)

          case exp.token
          when *CONVERTIBLE_ESCAPE_TOKENS
            JsRegex::Converter.convert(exp, context)
          when :literal
            exp.char.ord <= 0xFFFF &&
              Utils::Literals.escape_incompatible_bmp_literals(exp.char)
          end
        end
      end

      def simple_convert_literal_child(exp)
        if !context.u? &&
           exp.text =~ Utils::Literals::ASTRAL_PLANE_CODEPOINT_PATTERN &&
           !context.enable_u_option
          false
        elsif SET_LITERALS_REQUIRING_ESCAPE_PATTERN.match?(exp.text)
          "\\#{exp.text}"
        else
          Utils::Literals.escape_incompatible_bmp_literals(exp.text)
        end
      end

      SET_LITERALS_REQUIRING_ESCAPE_PATTERN = Regexp.union(%w<( ) [ ] { } / - |>)
      SET_SPECIFIC_ESCAPES_PATTERN = /[\^\-]/.freeze
      CONVERTIBLE_ESCAPE_TOKENS = %i[control meta_sequence bell escape octal] +
        Utils::Escapes::ESCAPES_SHARED_BY_RUBY_AND_JS
    end
  end
end
