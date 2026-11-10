# frozen_string_literal: true

require_relative 'model'

# Ruby's empty-loop check observes capture updates as well as input progress.
# Updating an absent/nonempty capture permits another iteration; updating an
# already-empty capture at a new position fails that path. Stable empty updates
# terminate the loop. Synthetic aliases keep these tests bound to exact copies.
class JsRegex::SecondPass::Compiler::EmptyIteration
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def initialize(history, whole_capture: nil)
    @history = history
    @whole_capture = whole_capture
    @updates = []
  end

  def call(body)
    start = Compiler::Occurrence.new
    marked = mark_captures(body)
    advance = negative(value(start))
    changed = @updates.map { |current, old| participation(current[0], previous(old, :changed)) }
    moved = @updates.map { |current, old| participation(current[0], previous(old, :moved)) }
    continuing = choice([advance, *changed])
    stopping = sequence(negative(continuing), negative(choice(moved)))
    [sequence(mark(start), marked), continuing, stopping]
  end

  private

  def mark_captures(expression)
    return expression if expression.instance_of?(String)
    children = expression.children.map { |child| mark_captures(child) }
    result = expression.with(children: children)
    return result unless expression.kind == :capture
    return result if @whole_capture && !expression.reference.capture.equal?(@whole_capture)

    captured = Compiler::Occurrence.new
    finish = Compiler::Occurrence.new
    alias_capture = Expression.new(:capture, [result], reference: captured,
                                  nonempty: expression.nonempty, nullable: expression.nullable)
    old = @history.fetch(expression.reference.capture, [])
    @updates << [[captured, finish], old]
    @history[expression.reference.capture] = [[captured, finish], *old]
    sequence(alias_capture, mark(finish))
  end

  def previous(history, kind)
    history.reverse_each.reduce(kind == :changed ? sequence : failure) do |fallback, (captured, finish)|
      test = if kind == :changed
               at_end(negative(value(captured)))
             else
               sequence(at_end(value(captured)), negative(value(finish)))
             end
      participation(captured, test, fallback)
    end
  end

  def participation(reference, present, absent = failure)
    Expression.new(:conditional, [present, absent], reference: reference)
  end

  def mark(reference)
    Expression.new(:lookahead, [Expression.new(:capture, ['[\\s\\S]*'], reference: reference, nullable: true)])
  end

  def value(reference)
    Expression.new(:value, [], reference: reference)
  end

  def at_end(test)
    Expression.new(:lookahead, ['[\\s\\S]*', '(?![\\s\\S])', test])
  end

  def negative(test)
    Expression.new(:negative_lookahead, [test])
  end

  def sequence(*children)
    Expression.new(:group, children)
  end

  def choice(children)
    return failure if children.empty?
    sequence(Expression.new(:choice, children.map { |part| Expression.new(:branch, [part]) }))
  end

  def failure
    Expression.new(:opaque, ['(?!)'])
  end
end
