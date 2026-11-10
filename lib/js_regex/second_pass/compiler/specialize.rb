# frozen_string_literal: true

require_relative 'model'

class JsRegex::SecondPass::Compiler::Specialize
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, states)
    new(states).rewrite(expression)
  end

  # Keep syntactic capture slots, but no participating values or assertions.
  def self.disable(expression)
    captures = []
    Compiler.walk(expression) do |part|
      next unless part.kind == :capture

      empty = Expression.new(:capture, [], reference: part.reference, nullable: true)
      quantity = Compiler::Quantity.from_text('{0}')
      captures << Expression.new(:repeat, [empty], quantity: quantity)
    end
    Expression.new(:sequence, captures)
  end

  def initialize(states)
    @states = states
  end

  def rewrite(expression)
    return expression if expression.instance_of?(String)

    case expression.kind
    when :backreference
      return Expression.new(:opaque, ['(?!)']) if @states[expression.reference] == false
    when :value
      return Expression.new(:sequence, expression.children) if @states[expression.reference] == false
    when :history, :multiplex
      children = expression.children.reject { |child| @states[child.reference] == false }
      return Expression.new(:opaque, ['(?!)']) if children.empty?
      expression = expression.with(children: children)
    when :conditional
      return select(expression.children, @states[expression.reference]) if @states.key?(expression.reference)
    when :capture_conditional
      references = expression.children.first.children.map(&:reference)
      return select(expression.children.drop(1), true) if references.any? { |ref| @states[ref] == true }
      return select(expression.children.drop(1), false) if references.all? { |ref| @states[ref] == false }
    end
    children = expression.children.map { |child| rewrite(child) }
    children == expression.children ? expression : expression.with(children: children)
  end

  private

  def select(branches, present)
    selected = present ? 0 : 1
    Expression.new(:group, branches.each_with_index.map do |branch, index|
      index == selected ? rewrite(branch) : self.class.disable(branch)
    end)
  end
end
