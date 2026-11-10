# frozen_string_literal: true

require_relative 'analysis'
require_relative 'specialize'
require_relative 'character_facts'

class JsRegex::SecondPass::Compiler::SimplifyLoops
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, analysis: nil)
    analysis ||= Compiler::Analysis.new(expression)
    return expression unless analysis.bounded_capture_loops || analysis.unbounded_capture_loops || analysis.nullable_order_loops

    new(expression, analysis).rewrite(expression, true)
  end

  def initialize(expression, analysis)
    @analysis = analysis
    @references = analysis[expression].references
    @characters = Compiler::CharacterFacts.new(analysis)
  end

  # If the entire continuation can always succeed, a lazy loop never needs to
  # try another iteration. Carry that proof through passive/capture boundaries;
  # a locally empty tail alone says nothing about an enclosing continuation.
  def rewrite(expression, tail_succeeds)
    return expression if expression.instance_of?(String)

    if expression.kind == :repeat
      quantity = expression.quantity
      if tail_succeeds && quantity.mode == :lazy && quantity.min <= 1
        return Compiler::Specialize.disable(expression) if quantity.min.zero?
        return rewrite(expression.children.first, true)
      end
      return expression unless @analysis.nullable_order_loops

      body = expression.children.first
      rewritten = rewrite(body, false)
      if quantity.mode == :greedy && quantity.min.zero? && quantity.max == 1 &&
         @analysis[body].empty == :always && @analysis[body].definitions.any? &&
         @analysis[body].definitions.all? { |reference| @references.fetch(reference, 0).zero? }
        # JS greedy optionals skip an empty body and may consume instead. An
        # explicit first arm permits Ruby's empty capture update, keeping the
        # same slots and leaving a bypass available after continuation failure.
        # Referenced captures receive this expansion with their continuation in
        # LowerNullableChoices; leave those in its cheaper optional form here.
        branches = [Expression.new(:branch, [rewritten]), Expression.new(:branch)]
        return Expression.new(:group, [Expression.new(:choice, branches)])
      end
      if quantity.max != 0 && quantity.mode != :possessive &&
         @analysis[body].definitions.empty? && @analysis[body].references.empty? &&
         @characters.empty_first?(body) && @characters.regular?(body)
        # Ruby stops on the first empty iteration, even below the minimum.
        # After that continuation fails, consuming paths grow the match in lazy
        # order. Empty paths have no capture/reference effects, so duplicate
        # visits can be omitted; the original finite maximum still applies.
        return Expression.new(:sequence) if tail_succeeds
        if quantity.mode == :lazy && quantity.min.zero?
          return rewritten.equal?(body) ? expression : expression.with(children: [rewritten])
        end
        text = quantity.max < 0 ? '*?' : (quantity.max == 1 ? '??' : "{0,#{quantity.max}}?")
        return Expression.new(:repeat, [rewritten], quantity: Compiler::Quantity.from_text(text))
      end
      return rewritten.equal?(body) ? expression : expression.with(children: [rewritten])
    end
    if [:lookahead, :negative_lookahead, :atomic].include?(expression.kind)
      # Keep the boundary in place and preserve internal backtracking order.
      # An outside continuation cannot justify dropping a path in an assertion
      # or in the lookahead used to implement an atomic group.
      tail_succeeds = false
    elsif ![:sequence, :branch, :group, :capture, :choice].include?(expression.kind)
      return expression
    end

    children = expression.children.reverse_each.map do |child|
      rewritten = rewrite(child, tail_succeeds)
      tail_succeeds &&= @analysis[child].empty == :always unless expression.kind == :choice
      rewritten
    end.reverse
    result = children == expression.children ? expression : expression.with(children: children)
    collapse_reference_runs(result, expression) || result
  end

  private

  # A greedy star's language is closed under concatenation. Its captured value
  # cannot match immediately after its preferred maximal run. A required read,
  # greedy repetition, or multiple required iterations reaches a final empty
  # capture before retrying shorter runs. Later backtracking revisits longer
  # endpoints before reaching the next shorter one;
  # a tail that cannot read this capture has already failed at those endpoints.
  def collapse_reference_runs(expression, original)
    return if expression.kind == :choice || expression.children.length < 2
    children = nil
    # Inspect the original pair: recursive simplification may already have
    # removed an optional reference, but its capture value still needs preserving.
    original.children.each_cons(2).with_index do |(loop_expression, reference), index|
      replacement = collapsed_run(loop_expression, reference)
      next unless replacement
      children ||= expression.children.dup
      children[index, 2] = replacement
    end
    expression.with(children: children) if children
  end

  def collapsed_run(loop_expression, reference)
    return if loop_expression.instance_of?(String) || reference.instance_of?(String)
    optional = reference.kind == :repeat && reference.quantity.min.zero? && reference.quantity.max == 1 &&
      reference.quantity.mode != :possessive
    reference = reference.children.first if optional
    return unless loop_expression.kind == :repeat && reference.kind == :backreference
    quantity = loop_expression.quantity
    return unless quantity.mode != :possessive && quantity.max < 0
    capture = Compiler.unwrap(loop_expression.children.first)
    wrappers = Compiler.capture_chain(capture)
    return unless wrappers.any? { |wrapper| wrapper.reference.equal?(reference.reference) }
    return unless wrappers.sum { |wrapper| @references.fetch(wrapper.reference, 0) } == 1 &&
      @analysis[capture].definitions.length == wrappers.length
    return unless wrappers.last.children.one? && !wrappers.last.children.first.instance_of?(String)
    run = Compiler.unwrap(wrappers.last.children.first)
    return unless run.kind == :repeat && run.quantity.mode == :greedy && run.quantity.min.zero? && run.quantity.max < 0
    body = run.children.first
    return unless @characters.nonempty?(body) && @characters.regular?(body)

    if optional && quantity.mode == :lazy && quantity.min <= 1
      # An optional reference adds no endpoint outside the greedy star's
      # language. One iteration preserves the preferred captured value; a lazy
      # bypass preserves the initially absent value of an outer star.
      if quantity.min.zero?
        bypass = Compiler::Quantity.from_text('??')
        capture = Expression.new(:repeat, [capture], quantity: bypass)
      end
      return [capture, Expression.new(:sequence)]
    end
    # Sole nested captures cover the same run and finish with the same value.
    empty = wrappers.reverse_each.reduce(Expression.new(:sequence)) do |body, wrapper|
      Expression.new(:capture, [body], reference: wrapper.reference, nullable: true)
    end
    [run, empty]
  end
end
