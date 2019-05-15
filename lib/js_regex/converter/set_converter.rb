# frozen_string_literal: true

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
        if directly_compatible?
          return expression.to_s(:base)
                           .gsub(%r{\\?([\f\n\r\t])}) { Regexp.escape($1) }
        end

        content = CharacterSet.of_expression(expression)
        if expression.case_insensitive? && !context.case_insensitive_root
          content = content.case_insensitive
        elsif !expression.case_insensitive? && context.case_insensitive_root
          warn_of_unsupported_feature('nested case-sensitive set')
        end

        if Converter.in_surrogate_pair_limit? { content.astral_part.size }
          content.to_s_with_surrogate_alternation
        else
          warn_of_unsupported_feature('large astral plane match of set')
          bmp_part = content.bmp_part
          bmp_part.empty? ? drop : bmp_part.to_s(in_brackets: true)
        end
      end

      def directly_compatible?
        if expression.case_insensitive? ^ context.case_insensitive_root
          # casefolding needed
          return
        end

        # check for children needing conversion (#each_expression is recursive)
        expression.each_expression do |exp|
          case exp.type
          when :literal
            # surrogate pair substitution needed if astral
            next if exp.text.ord <= 0xFFFF
          when :set
            # conversion needed for nested sets, intersections
            next if exp.token.equal?(:range)
          when :type
            next if TypeConverter::TYPES_SHARED_BY_RUBY_AND_JS.include?(exp.token)
          when :escape
            next if EscapeConverter::ESCAPES_SHARED_BY_RUBY_AND_JS.include?(exp.token)
          end
          return
        end
        true
      end
    end
  end
end
