# frozen_string_literal: true

require_relative 'analysis'
require_relative 'capture_histories'
require_relative 'empty_iteration'
require_relative 'character_facts'
require_relative 'tail_filter'

class JsRegex::SecondPass::Compiler::ExpandBoundedLoops
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, analysis: nil)
    new(expression, analysis).call(expression)
  end

  def initialize(expression, analysis)
    @analysis = analysis || Compiler::Analysis.new(expression)
    @references = @analysis[expression].references
    @expanded = {}
    @prefixes = {}
  end

  def call(expression)
    result = expand(expression)
    Compiler::CaptureHistories.call(result, @expanded.keys)
  end

  private

  def expand(expression)
    return expression if expression.instance_of?(String)

    sequence = [:sequence, :group, :branch, :capture].include?(expression.kind)
    children = expression.children.each_with_index.flat_map do |child, index|
      expanded = expand(child)
      if sequence && @prefixes.key?(expanded)
        # Reject impossible suffixes before exploring partitions in the finite
        # required prefix, not only after reaching its unbounded tail.
        following = Expression.new(:sequence, expression.children.drop(index + 1))
        filter = Compiler::TailFilter.new(@analysis).call(following)
        next [filter, *expanded.children] if filter
      end
      sequence && @prefixes.key?(expanded) ? expanded.children : [expanded]
    end
    result = children == expression.children ? expression : expression.with(children: children)
    return result unless expression.kind == :repeat
    quantity = expression.quantity
    return result unless quantity.max > 1 || (quantity.max < 0 && quantity.min > 1)

    original_body = expression.children.first
    facts = @analysis[original_body]
    # Empty iterations can stop before the required minimum. For a scalar
    # whole-iteration capture, the finite prefix can use the existing empty
    # update checks and bypass the unbounded tail when it stops early.
    nullable_prefix = facts.empty != :never
    if quantity.max < 0 && nullable_prefix
      return result unless whole_capture?(original_body) && facts.references.empty?
    end
    referenced = facts.may_capture.select { |ref| @references.fetch(ref, 0) > 0 }
    if referenced.empty?
      return result unless facts.empty == :always && whole_capture?(original_body)
      @characters ||= Compiler::CharacterFacts.new(@analysis)
      return result unless @characters.empty_first?(original_body)
    end
    # Native repetitions already preserve captures updated by every iteration,
    # provided no reference reads an earlier iteration from within the loop.
    if facts.empty == :never && referenced.all? { |ref| facts.must_capture.include?(ref) && !facts.entry_reads.include?(ref) }
      return result
    end

    if facts.definitions.any? { |ref| @analysis[@analysis.captures.fetch(ref)].references.fetch(ref, 0) > 0 }
      raise Compiler::Unsupported, 'self-references inside bounded capture loops'
    end

    facts.definitions.each { |ref| @expanded[ref.capture] = true }
    body = result.children.first
    if quantity.max < 0
      prefix_quantity = Compiler::Quantity.from_text("{#{quantity.min - 1}}")
      tail_quantity = Compiler::Quantity.from_text(quantity.mode == :lazy ? '+?' : '+')
      tail = Expression.new(:repeat, [body], quantity: tail_quantity)
      prefix = unroll(body, prefix_quantity, empty_iterations: nullable_prefix, tail: nullable_prefix ? tail : nil)
      result = nullable_prefix ? prefix : Expression.new(:group, [prefix, tail])
      @prefixes[result] = true
      result
    else
      unroll(body, quantity, empty_iterations: facts.empty != :never)
    end
  end

  def unroll(body, quantity, empty_iterations:, tail: nil)
    whole_capture = whole_capture?(body) if empty_iterations
    return unroll_progress(body, quantity) if !tail && whole_capture
    observed = Compiler.unwrap(body).reference.capture if whole_capture
    history = {}
    iterations = Array.new(quantity.max) do
      copy = Compiler.copy(body)
      empty_iterations ? Compiler::EmptyIteration.new(history, whole_capture: observed).call(copy) : [copy, nil, nil]
    end
    tail ||= Expression.new(:sequence)
    quantity.max.downto(1) do |iteration|
      part, continuing, stopping = iterations[iteration - 1]
      after = if continuing
                choice([Expression.new(:group, [continuing, tail]), stopping])
              else
                tail
              end
      current = Expression.new(:group, [part, after])
      if iteration > quantity.min
        alternatives = [current, Expression.new(:sequence)]
        alternatives.reverse! if quantity.mode == :lazy
        tail = choice(alternatives)
      else
        tail = current
      end
    end
    tail
  end

  # When the observed captures cover each whole iteration, an empty value cannot move
  # without an intervening nonempty update. Two successive empty iterations are
  # then sufficient to stop; no aliases or conditional capture checks are needed.
  def unroll_progress(body, quantity)
    positions = Array.new(quantity.max) { |index| Compiler::Occurrence.new if index + 2 < quantity.max }
    tail = Expression.new(:sequence)
    quantity.max.downto(1) do |iteration|
      parts = [Compiler.copy(body), tail]
      if positions[iteration - 1]
        capture = Expression.new(:capture, ['[\\s\\S]*'], reference: positions[iteration - 1], nullable: true)
        parts.unshift(Expression.new(:lookahead, [capture]))
      end
      previous = positions[iteration - 3] if iteration > 2
      value = Expression.new(:value, [], reference: previous) if previous
      parts.unshift(Expression.new(:negative_lookahead, [value])) if previous
      current = Expression.new(:group, parts)
      if iteration > quantity.min
        alternatives = [current, Expression.new(:sequence)]
        alternatives.reverse! if quantity.mode == :lazy
        tail = choice(alternatives)
      else
        tail = previous ? choice([current, Expression.new(:lookahead, [value])]) : current
      end
    end
    tail
  end

  def whole_capture?(body)
    expression = Compiler.unwrap(body)
    return false unless expression.kind == :capture
    captures = 0
    Compiler.walk(body) { |part| captures += 1 if part.kind == :capture }
    captures == Compiler.capture_chain(expression).length
  end

  def choice(alternatives)
    branches = alternatives.map { |part| Expression.new(:branch, [part]) }
    Expression.new(:group, [Expression.new(:choice, branches)])
  end
end
