# frozen_string_literal: true

require_relative 'analysis'
require_relative 'literal_word'
require_relative 'capture_histories'
require_relative 'tail_filter'

# A lazy loop over two disjoint character runs can retain both final values by
# alternating runs. Continuation probes preserve the order of possible splits
# within a greedy run; a plain permutation of the final captures would not.
class JsRegex::SecondPass::Compiler::LowerLazyRuns
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression
  attr_reader :split_captures

  def self.call(expression, analysis: nil)
    pass = new(expression, analysis)
    result = pass.rewrite(expression)
    Compiler::CaptureHistories.call(result, pass.split_captures)
  end

  def initialize(expression, analysis)
    @analysis = analysis || Compiler::Analysis.new(expression)
    @references = @analysis[expression].references
    @split_captures = []
  end

  def rewrite(expression)
    return expression if expression.instance_of?(String)
    return expression unless [:sequence, :group, :capture, :branch, :choice, :lookahead, :negative_lookahead, :atomic].include?(expression.kind)

    unless [:choice, :atomic].include?(expression.kind)
      expression.children.each.with_index do |child, index|
        next if child.instance_of?(String) || child.kind != :repeat
        following = Expression.new(:sequence, expression.children.drop(index + 1))
        candidate = candidates(child, following)
        next unless candidate
        captures, wrappers = candidate

        next unless @analysis.closed?(expression.children.drop(index))

        @split_captures |= wrappers.map { |wrapper| wrapper.reference.capture }
        replacement = Runs.new(captures, following, wrappers).compile
        filter = Compiler::TailFilter.new(@analysis).call(following)
        replacement = Expression.new(:group, [filter, replacement]) if filter
        return expression.with(children: [*expression.children.take(index).map { |part| rewrite(part) }, replacement])
      end
    end
    children = expression.children.map { |child| rewrite(child) }
    children == expression.children ? expression : expression.with(children: children)
  end

  private

  def candidates(expression, following)
    return if expression.instance_of?(String) || expression.kind != :repeat
    quantity = expression.quantity
    return unless quantity.max < 0 && quantity.min <= 1 && quantity.mode == :lazy
    body = Compiler.unwrap(expression.children.first)
    wrappers = []
    while body.kind == :capture && body.children.one?
      wrappers << body
      body = Compiler.unwrap(body.children.first)
    end
    return unless body.kind == :choice && body.children.length == 2 && @analysis[body].references.empty?
    captures = body.children.map { |branch| Compiler.unwrap(branch) }
    return unless captures.all? { |capture| capture.kind == :capture && @analysis[capture].definitions.one? }
    words = captures.map { |capture| character_run(capture) }
    return unless words.all? && CharacterSet.of_string(words[0]).case_insensitive.disjoint?(CharacterSet.of_string(words[1]).case_insensitive)

    references = following.children.take(2)
    return unless references.length == 2 && references.all? { |part| !part.instance_of?(String) && part.kind == :backreference }
    return unless references.map(&:reference).sort_by(&:object_id) == captures.map(&:reference).sort_by(&:object_id)
    return unless captures.all? { |capture| @references[capture.reference] == 1 }

    ordered = references.map { |reference| captures.find { |capture| capture.reference.equal?(reference.reference) } }
    [ordered, wrappers]
  end

  def character_run(capture)
    body = Compiler.unwrap(capture.children.first)
    return unless capture.children.one? && body.kind == :repeat && body.quantity.mode == :greedy &&
      body.quantity.min == 1 && body.quantity.max < 0
    word = Compiler::LiteralWord.call(body.children.first)
    word if word && word.length == 1
  end

  class Runs
    def initialize(captures, following, wrappers)
      @left, @right = captures
      @following = following
      @wrappers = wrappers
    end

    def compile
      right, state = run(@right, {})
      pair, state = pair(state)
      sequence(repeat(right, '??'), repeat(pair, '*?'), endings(state))
    end

    private

    def endings(state)
      probe_capture, probe_state = capture(@left, state)
      single_probe = assertion(:lookahead, sequence(probe_capture, tail(probe_state)))
      first, after = capture(@left, state)
      shorter = sequence(discarded(@left), assertion(:negative_lookahead, value(probe_state[@left.reference].first)),
                         first, continuation(after))
      first, after = capture(@left, state)
      single = sequence(single_probe, assertion(:negative_lookahead, choice(future(state), shorter)), first, tail(after))

      position = Compiler::Occurrence.new
      prefix = Expression.new(:capture, [discarded(@left)], reference: position, nonempty: true)
      first, after = capture(@left, state)
      split_probe = assertion(:lookahead, sequence(prefix, first, tail(after)))
      first, after = capture(@left, state)
      earlier = sequence(value(position), repeat(discarded(@left), '??'), first, continuation(after))
      first, after = capture(@left, state)
      split = sequence(split_probe, assertion(:negative_lookahead, choice(future(state), earlier)),
                       Expression.new(:backreference, [], reference: position), first, tail(after))
      choice(tail(state), single, split)
    end

    def future(state)
      first, after = capture(@left, state)
      sequence(first, continuation(after))
    end

    def continuation(state)
      right, after = run(@right, state)
      pair, after = pair(after)
      left, last = run(@left, after)
      sequence(right, repeat(pair, '*?'), choice(tail(after), sequence(left, tail(last))))
    end

    def pair(state)
      left, state = run(@left, state)
      right, state = run(@right, state)
      [sequence(left, right), state]
    end

    def run(original, state)
      captured, after = capture(original, state)
      # Skipped iterations contain no captures and repeat one character. One
      # optional greedy run visits the same positions in the same first-visit
      # order as (x+)*?, without retrying exponentially many identical splits.
      [sequence(repeat(discarded(original), '??'), captured), after]
    end

    def capture(original, state)
      reference = Compiler::Occurrence.new(original.reference.capture)
      captured = original.with(reference: reference)
      captured = @wrappers.reverse_each.reduce(captured) do |body, wrapper|
        occurrence = Compiler::Occurrence.new(wrapper.reference.capture)
        wrapper.with(children: [body], reference: occurrence)
      end
      [captured, state.merge(original.reference => [reference, *state.fetch(original.reference, [])])]
    end

    def discarded(capture)
      Expression.new(:group, capture.children)
    end

    def tail(state)
      original = Compiler.copy(@following)
      references = original.children.take(2).map do |reference|
        candidates = state.fetch(reference.reference, []).map do |occurrence|
          Expression.new(:backreference, [], reference: occurrence)
        end
        Expression.new(:history, candidates)
      end
      original.with(children: [*references, *original.children.drop(2)])
    end

    def repeat(body, text)
      quantity = Compiler::Quantity.from_text(text)
      Expression.new(:native_repeat, [Expression.new(:group, [body])], quantity: quantity)
    end

    def sequence(*children)
      Expression.new(:group, children)
    end

    def choice(*children)
      Expression.new(:group, [Expression.new(:choice, children.map { |child| Expression.new(:branch, [child]) })])
    end

    def assertion(kind, body)
      Expression.new(kind, [body])
    end

    def value(reference)
      Expression.new(:value, [], reference: reference)
    end
  end
end
