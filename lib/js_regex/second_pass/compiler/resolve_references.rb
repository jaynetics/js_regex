# frozen_string_literal: true

require_relative 'analysis'
require_relative 'specialize'
require_relative 'literal_word'
require_relative 'character_facts'

class JsRegex::SecondPass::Compiler::ResolveReferences
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, analysis: nil)
    new(expression, analysis).rewrite(expression, {}).first
  end

  def initialize(expression, analysis = nil)
    @analysis = analysis || Compiler::Analysis.new(expression)
    @references = @analysis[expression].references
    @backward_captures = []
  end

  # State describes participation at this position, not merely whether a capture
  # occurs somewhere in the tree. Choices merge true/false into :maybe; captures
  # become present only after their closing boundary.
  def rewrite(expression, state)
    return [expression, state] if expression.instance_of?(String)

    case expression.kind
    when :backreference
      return [reference(expression, state), state]
    when :value
      status = state.fetch(expression.reference, false)
      return [status == false ? Expression.new(:sequence) : backward_value(expression, status), state]
    when :history, :multiplex
      return [candidates(expression, state), state]
    when :conditional, :capture_conditional
      return condition(expression, state)
    when :choice
      results = expression.children.map { |child| rewrite(child, state.dup) }
      states = results.each_with_index.reject { |_, index| expression.children[index].kind == :omitted_branch }.map { |result, _| result.last }
      return [replace_children(expression, results.map(&:first)), merge(states, state)]
    when :repeat, :native_repeat
      return repetition(expression, state)
    when :dropped, :omitted_branch
      return [expression, state]
    when :keep
      unsupported!('keep marks')
    when :opaque
      unsupported!('capture semantics inside an opaque fragment') if @analysis[expression].references.any? || @analysis[expression].definitions.any?
      return [expression, state]
    when :lookbehind, :negative_lookbehind
      return lookbehind(expression, state)
    end

    rewrite_children(expression, state)
  end

  private

  def rewrite_children(expression, state)
    current = state.dup
    children = expression.children.map do |child|
      rewritten, current = rewrite(child, current)
      rewritten
    end
    current[expression.reference] = true if expression.kind == :capture
    current = state if [:negative_lookahead, :negative_lookbehind, :absence].include?(expression.kind)
    [replace_children(expression, children), current]
  end

  def lookbehind(expression, state)
    previous = @backward_captures
    @backward_captures |= @analysis[expression].definitions
    rewrite_children(expression, state)
  ensure
    @backward_captures = previous
  end

  # JavaScript evaluates lookbehind backwards. A constant value known present
  # in Ruby's forward prefix can be inlined; a dynamic internal value cannot.
  # Captures defined outside the assertion already have their runtime values.
  def backward_value(expression, status)
    return expression unless @backward_captures.include?(expression.reference)
    unsupported!('uncertain capture participation inside lookbehind') unless status == true
    word = Compiler::LiteralWord.call(@analysis.captures.fetch(expression.reference))
    unsupported!('variable capture values inside lookbehind') unless word
    group(word, *expression.children)
  end

  def repetition(expression, state)
    quantity = expression.quantity
    return [Compiler::Specialize.disable(expression), state] if quantity.max.zero?

    # Lowering marks native_repeat only after proving JavaScript's reset-on-entry
    # behavior correct for its generated captures. Input repeat nodes still need
    # the cross-iteration check, including those nested in generated expressions.
    if expression.kind == :repeat
      facts = @analysis[expression.children.first]
      referenced = facts.may_capture.select { |ref| @references.fetch(ref, 0) > 0 }
      if quantity.mode == :greedy && (quantity.min.zero? || quantity.max != 1) &&
         facts.empty == :always && referenced.empty?
        @characters ||= Compiler::CharacterFacts.new(@analysis)
        if @characters.empty_first?(expression.children.first) && @characters.fixed_width(expression.children.first) != 0
          unsupported!('empty-first ordering inside an unobserved repeated body')
        end
      end
      if quantity.max < 0 || quantity.max > 1
        safe = facts.empty == :never && referenced.all? do |ref|
          facts.must_capture.include?(ref) && !facts.entry_reads.include?(ref)
        end
        unsupported!('referenced captures in repeated iterations') unless referenced.empty? || safe
      end
    end
    body, after = rewrite(expression.children.first, state.dup)
    after = merge([state, after], state) if quantity.min.zero?
    [replace_children(expression, [body]), after]
  end

  def reference(expression, state)
    case state.fetch(expression.reference, false)
    when false then failure
    when true then backward_value(expression, true)
    else
      group(presence(expression.reference, true), expression)
    end
  end

  def candidates(expression, state)
    result = expression.children.reverse_each.reduce(nil) do |fallback, candidate|
      if expression.kind == :multiplex && candidate.kind == :history
        preferred = candidates(candidate, state)
        next fallback ? choice(preferred, group(Expression.new(:negative_lookahead, [preferred]), fallback)) : preferred
      end
      status = state.fetch(candidate.reference, false)
      next fallback if status == false

      if expression.kind == :multiplex
        preferred = reference(candidate, state)
        # A matching duplicate-name value commits even if the continuation fails.
        fallback ? choice(preferred, group(Expression.new(:negative_lookahead, [preferred]), fallback)) : preferred
      elsif status == true
        backward_value(candidate, true) # A present history value commits.
      else
        preferred = group(presence(candidate.reference, true), candidate)
        fallback ? choice(preferred, group(presence(candidate.reference, false), fallback)) : preferred
      end
    end
    result || failure
  end

  def condition(expression, state)
    if expression.kind == :conditional
      references = [expression.reference]
      branches = expression.children
    else
      references = expression.children.first.children.map(&:reference)
      branches = expression.children.drop(1)
    end
    statuses = references.map { |ref| state.fetch(ref, false) }
    if statuses.include?(true) || statuses.all? { |status| status == false }
      selected = statuses.include?(true) ? 0 : 1
      after = state
      children = branches.each_with_index.map do |branch, index|
        if index == selected
          result, after = rewrite(branch, state.dup)
          result
        else
          Compiler::Specialize.disable(branch)
        end
      end
      return [Expression.new(:group, children), after]
    end

    possible = references.reject { |ref| state.fetch(ref, false) == false }
    present = choice(*possible.map { |ref| presence(ref, true) })
    absent = possible.map { |ref| presence(ref, false) }
    true_state = state.dup
    true_state[possible.first] = true if possible.one?
    false_state = state.merge(possible.to_h { |ref| [ref, false] })
    truthy, true_after = rewrite(branches.fetch(0), true_state)
    falsy, false_after = rewrite(branches[1] || Expression.new(:sequence), false_state)
    [choice(group(present, truthy), group(*absent, falsy)), merge([true_after, false_after], state)]
  end

  # At end of input, a JS backreference matches only if empty or unmatched.
  # Testing its negation there detects participation of a nonempty capture.
  def presence(reference, present)
    unsupported!('uncertain capture participation inside lookbehind') if @backward_captures.include?(reference)
    capture = @analysis.captures.fetch(reference)
    unsupported!('uncertain participation of a possibly-empty capture') unless capture.nonempty

    value = Expression.new(:value, [], reference: reference)
    test = present ? Expression.new(:negative_lookahead, [value]) : value
    Expression.new(:lookahead, ['[\\s\\S]*', '(?![\\s\\S])', test])
  end

  def merge(states, fallback)
    return fallback if states.empty?

    states.flat_map(&:keys).uniq.to_h do |reference|
      values = states.map { |state| state.fetch(reference, false) }.uniq
      [reference, values.length == 1 ? values.first : :maybe]
    end
  end

  def group(*children)
    Expression.new(:group, children)
  end

  def replace_children(expression, children)
    children == expression.children ? expression : expression.with(children: children)
  end

  def choice(*children)
    return failure if children.empty?
    return children.first if children.one?

    branches = children.map do |child|
      Expression.new(:branch, child.kind == :group ? child.children : [child])
    end
    group(Expression.new(:choice, branches))
  end

  def failure
    Expression.new(:opaque, ['(?!)'])
  end

  def unsupported!(reason)
    raise Compiler::Unsupported, reason
  end
end
