# frozen_string_literal: true

require 'character_set'

class JsRegex
  module Utils
    module CharSets
      def self.convert(expression, context)
        # Calculate the set without case folding so the original casing is
        # preserved when the JavaScript regexp already has the i flag.
        neutral_expression = expression.dup
        neutral_expression.options[:i] = false
        unless neutral_expression.terminal?
          neutral_expression.each_expression(true) { |exp| exp.options[:i] = false }
        end
        content = CharacterSet.of_expression(neutral_expression)

        if expression.case_insensitive? && !context.case_insensitive_root
          content = content.case_insensitive
        elsif !expression.case_insensitive? && context.case_insensitive_root
          context.warn_of("Dropped unsupported nested case-sensitive character set '#{expression}' "\
                          "at index #{expression.ts}")
        end

        if context.es_2015_or_higher?
          context.enable_u_option if content.astral_part?
          content.to_s(format: 'es6', in_brackets: true)
        else
          content.to_s_with_surrogate_ranges
        end
      end
    end
  end
end
