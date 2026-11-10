# frozen_string_literal: true

require_relative 'specialize'

class JsRegex::SecondPass::Compiler::Continuation
  Compiler = JsRegex::SecondPass::Compiler

  def initialize(expression)
    @expression = expression
    freeze
  end

  # Copy the prefix and continuation together. Copying the tail alone would
  # leave its references pointing at the original prefix's capture occurrences.
  def branch(prefix, states = {})
    tail = Compiler::Specialize.call(@expression, states)
    combined = Compiler::Expression.new(:branch, [prefix, tail])
    combined = yield(combined) if block_given?
    Compiler.copy(combined)
  end
end
