# frozen_string_literal: true

require_relative 'character_facts'

# Consuming paths tried before a regular expression's first unconditional empty
# path. Captures are omitted: callers use this only after proving that the
# observed captures all cover the entire iteration.
class JsRegex::SecondPass::Compiler::BeforeEmpty
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression
  NotApplicable = Class.new(StandardError)

  def initialize(characters)
    @characters = characters
  end

  def call(expression)
    return discard_captures(expression) if @characters.nonempty?(expression)
    return if @characters.empty_first?(expression)
    raise NotApplicable if expression.instance_of?(String)

    case expression.kind
    when :sequence, :group, :branch, :capture
      choices = expression.children.each_with_index.map do |child, index|
        before = call(child)
        sequence([before, *expression.children.drop(index + 1).map { |part| discard_captures(part) }]) if before
      end.compact
      choice(choices)
    when :choice
      choices = []
      expression.children.each do |child|
        next if child.kind == :omitted_branch
        before = call(child)
        choices << before if before
        break unless @characters.nonempty?(child)
      end
      choice(choices)
    when :repeat
      quantity = expression.quantity
      body = expression.children.first
      return call(body) if quantity.max == 1
      raise NotApplicable unless quantity.min.zero? && quantity.mode == :greedy && @characters.nonempty?(body)
      text = quantity.max < 0 ? '+' : "{1,#{quantity.max}}"
      Expression.new(:repeat, [discard_captures(body)], quantity: Compiler::Quantity.from_text(text))
    else
      raise NotApplicable
    end
  end

  private

  def discard_captures(expression)
    return expression if expression.instance_of?(String)
    children = expression.children.map { |child| discard_captures(child) }
    expression.kind == :capture ? sequence(children) : expression.with(children: children)
  end

  def sequence(children)
    Expression.new(:group, children)
  end

  def choice(children)
    return if children.empty?
    return children.first if children.one?
    sequence([Expression.new(:choice, children.map { |child| Expression.new(:branch, [child]) })])
  end
end
