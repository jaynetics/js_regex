# frozen_string_literal: true

require_relative 'model'

# Bind split definitions by logical identity. Final emission alone assigns
# numbers; history order is separate from duplicate-name value fallback.
class JsRegex::SecondPass::Compiler::CaptureHistories
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, captures)
    return expression if captures.empty?
    occurrences = Hash.new { |hash, key| hash[key] = [] }
    Compiler.walk(expression) do |part|
      if part.kind == :capture && captures.include?(part.reference.capture)
        occurrences[part.reference.capture].unshift(part.reference)
      end
    end
    new(occurrences).rewrite(expression)
  end

  def initialize(occurrences)
    @occurrences = occurrences
  end

  def rewrite(expression)
    return expression if expression.instance_of?(String)

    children = expression.children.map { |child| rewrite(child) }
    reference = expression.reference
    copies = @occurrences[reference.capture] if reference && @occurrences.key?(reference.capture)
    if copies && expression.kind == :backreference
      return Expression.new(:history, copies.map { |copy| Expression.new(:backreference, [], reference: copy) })
    elsif copies && expression.kind == :conditional
      checks = Expression.new(:sequence, copies.map { |copy| Expression.new(:sequence, [], reference: copy) })
      return Expression.new(:capture_conditional, [checks, *children])
    elsif copies && expression.kind == :value
      # Unlike a required backreference, an unmatched value check succeeds empty.
      # Select by participation so a later empty capture wins over older values.
      return copies.reverse_each.reduce(Expression.new(:sequence, children)) do |fallback, copy|
        value = Expression.new(:value, children, reference: copy)
        Expression.new(:conditional, [value, fallback], reference: copy)
      end
    elsif expression.kind == :history
      children = children.flat_map { |child| child.kind == :history ? child.children : [child] }
    elsif expression.kind == :capture_conditional
      checks = expression.children.first.children.flat_map do |check|
        replacements = @occurrences.fetch(check.reference.capture, [check.reference])
        replacements.map { |copy| Expression.new(:sequence, [], reference: copy) }
      end
      children[0] = Expression.new(:sequence, checks)
    end
    children == expression.children ? expression : expression.with(children: children)
  end
end
