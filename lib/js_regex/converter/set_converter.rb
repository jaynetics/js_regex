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
        return pass_through_with_escaping if directly_compatible?

        content = CharacterSet.of_expression(expression)
        if expression.case_insensitive? && !context.case_insensitive_root
          content = content.case_insensitive
        elsif !expression.case_insensitive? && context.case_insensitive_root
          warn_of_unsupported_feature('nested case-sensitive set')
        end

        content.to_s_with_surrogate_ranges
      end

      def directly_compatible?
        all_children_directly_compatible? && !casefolding_needed?
      end

      def all_children_directly_compatible?
        # note that #each_expression is recursive
        expression.each_expression do |exp|
          return unless child_directly_compatible?(exp)
        end
      end

      def child_directly_compatible?(exp)
        case exp.type
        when :literal
          # surrogate pair substitution needed if astral
          exp.text.ord <= 0xFFFF
        when :set
          # conversion needed for nested sets, intersections
          exp.token.equal?(:range)
        when :type
          TypeConverter.directly_compatible?(exp)
        when :escape
          EscapeConverter::ESCAPES_SHARED_BY_RUBY_AND_JS.include?(exp.token)
        end
      end

      def casefolding_needed?
        expression.case_insensitive? ^ context.case_insensitive_root
      end

      def pass_through_with_escaping
        expression.to_s(:base).gsub(%r{([\f\n\r\t])|(/)}) do
          $1 ? Regexp.escape($1) : "\\#{$2}"
        end
      end
    end
  end
end
