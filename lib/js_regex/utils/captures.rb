# frozen_string_literal: true

class JsRegex
  module Utils
    module Captures
      # Unlike assertions and backreferences, these expressions can match an
      # empty string at every input position, regardless of surrounding text.
      def self.nullable?(expression, quantified = false)
        return true if quantified && expression.quantifier && expression.quantifier.min.zero?

        case expression.type
        when :literal
          expression.text.empty?
        when :group, :expression
          !expression.terminal? && expression.token != :absence &&
            expression.expressions.all? { |child| nullable?(child, true) }
        when :meta
          expression.token == :alternation && expression.expressions.any? { |child| nullable?(child, true) }
        else
          false
        end
      end

      # A participating capture ignores its own quantifier. Treat backreferences
      # conservatively rather than following potentially recursive references.
      def self.nonempty?(expression, quantified = false)
        return false if quantified && expression.quantifier && expression.quantifier.min.zero?

        case expression.type
        when :literal
          !expression.text.empty?
        when :escape, :property, :nonproperty, :set, :type
          true
        when :group, :expression
          !expression.terminal? && expression.token != :absence &&
            expression.expressions.any? { |child| nonempty?(child, true) }
        when :meta
          expression.token == :dot ||
            (expression.token == :alternation && expression.expressions.all? { |child| nonempty?(child, true) })
        else
          false
        end
      end
    end
  end
end
