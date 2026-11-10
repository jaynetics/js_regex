# frozen_string_literal: true

require_relative 'analysis'

# Remove an optional bypass when a required reference makes it fail anyway.
# This preserves capture identities and avoids distributing enclosing captures
# or backtracking prefixes into copied continuations.
class JsRegex::SecondPass::Compiler::RequireCaptures
  Compiler = JsRegex::SecondPass::Compiler

  def self.call(expression, analysis: nil)
    analysis ||= Compiler::Analysis.new(expression)
    return expression unless analysis.optional_captures
    new(analysis).rewrite(expression, [])
  end

  def initialize(analysis)
    @analysis = analysis
  end

  def rewrite(expression, required)
    return expression if expression.instance_of?(String)
    required |= @analysis.required_references(expression)

    if expression.kind == :repeat
      quantity = expression.quantity
      return expression unless quantity.max == 1 && quantity.mode != :possessive
      body = expression.children.first
      if quantity.min.zero? && !(@analysis[body].definitions & required).empty?
        return rewrite(body, required)
      end
    elsif ![:sequence, :group, :branch, :choice, :capture, :conditional, :capture_conditional].include?(expression.kind)
      # Assertions and atomics commit choices before the outside continuation.
      return expression
    end

    children = expression.children.map { |child| rewrite(child, required) }
    # Removing a bypass can make an ancestor non-nullable. Its previous proof of
    # emptiness must not survive that restriction of the accepted language.
    children == expression.children ? expression : expression.with(children: children, nullable: false)
  end
end
