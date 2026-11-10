# frozen_string_literal: true

require_relative 'analysis'
require_relative 'continuation'
require_relative 'character_facts'
require_relative 'tail_filter'
require_relative 'lower_nullable_choices'
require_relative 'before_empty'
require_relative 'capture_histories'

class JsRegex::SecondPass::Compiler::LowerNullableLoops
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, analysis: nil, tail_succeeds: true)
    new(expression, analysis).rewrite(expression, tail_succeeds)
  end

  def initialize(expression, analysis)
    @analysis = analysis || Compiler::Analysis.new(expression)
    @references = @analysis[expression].references
    @characters = Compiler::CharacterFacts.new(@analysis)
  end

  def rewrite(expression, tail_succeeds = true)
    return expression if expression.instance_of?(String) || @analysis[expression].definitions.empty?
    if [:lookahead, :negative_lookahead, :atomic].include?(expression.kind)
      # A forward assertion commits its first complete internal match. Its
      # outside continuation cannot make that match backtrack.
      tail_succeeds = true
    elsif ![:sequence, :group, :branch, :capture, :choice].include?(expression.kind)
      return expression
    end

    unless [:choice, :atomic].include?(expression.kind)
      expression.children.each.with_index do |child, index|
        if tail_succeeds && !child.instance_of?(String) && child.kind == :capture &&
           (guarded = guard_capture(child, expression.children.drop(index + 1)))
          prefix = expression.children.take(index).map { |part| rewrite(part, false) }
          return expression.with(children: [*prefix, guarded, *expression.children.drop(index + 1)])
        end
        next unless (candidate = candidate(child))

        # Greedy stopping probes must see the complete continuation. A capture
        # boundary can hide a later failure even when all value reads are local.
        needs_tail = child.quantity.mode == :greedy || !@characters.empty_first?(candidate.first)
        next if needs_tail && !tail_succeeds
        next unless @analysis.closed?(expression.children.drop(index))

        following = Expression.new(:sequence, expression.children.drop(index + 1))

        capture, branches = candidate
        next if branches && !safe_empty_tail?(capture, branches, following)

        tail = self.class.call(following, tail_succeeds: tail_succeeds)
        replacement = branches ? lower_alternation(child, tail, capture, branches) : lower(child, tail)
        filter = Compiler::TailFilter.new(@analysis).call(following)
        replacement = Expression.new(:group, [filter, replacement]) if filter
        prefix = expression.children.take(index).map { |part| rewrite(part, false) }
        return expression.with(children: [*prefix, replacement])
      end
    end

    children = expression.children.dup
    (children.length - 1).downto(0) do |index|
      # Atomic IR stores the synthetic lookahead's capture and its consuming
      # reference as siblings; that first child has its own committed scope.
      tail_succeeds = true if expression.kind == :atomic
      child = expression.children[index]
      children[index] = rewrite(child, tail_succeeds)
      tail_succeeds &&= @analysis[child].empty == :always unless expression.kind == :choice
    end
    children == expression.children ? expression : expression.with(children: children)
  end

  private

  # A capture boundary can keep a stopping probe from seeing a failing suffix.
  # If the suffix neither defines captures nor reads this region's captures,
  # testing it just before closing the group preserves both its value and the
  # original backtracking order. The real suffix still consumes outside it.
  def guard_capture(capture, following)
    return if following.empty? || !contains_candidate?(capture)
    return unless following.all? { |part| @analysis[part].definitions.empty? && !@analysis[part].references.key?(capture.reference) }
    return unless @analysis.closed?(capture.children)

    probe = Expression.new(:lookahead, following)
    filter = Compiler::TailFilter.new(@analysis).call(Expression.new(:sequence, following))
    guarded = capture.with(children: [filter, *capture.children, probe].compact)
    guarded = Compiler::LowerNullableChoices.call(guarded)
    lowered = self.class.call(guarded)
    lowered unless lowered.equal?(guarded)
  end

  def contains_candidate?(expression)
    return false if expression.instance_of?(String)
    return !!candidate(expression) if expression.kind == :repeat
    [:sequence, :group, :branch, :capture, :choice].include?(expression.kind) &&
      expression.children.any? { |child| contains_candidate?(child) }
  end

  def candidate(expression)
    return if expression.instance_of?(String) || expression.kind != :repeat

    quantity = expression.quantity
    return unless quantity.max < 0 && quantity.min <= 1 && quantity.mode != :possessive

    body = Compiler.unwrap(expression.children.first)
    branches = body.children.map { |branch| Compiler.unwrap(branch) } if body.kind == :choice
    capture = branches ? branches.find { |branch| branch.kind == :capture } : body
    return unless capture && capture.kind == :capture && capture.nullable

    facts = @analysis[expression]
    aliases = Compiler.capture_chain(capture)
    observed = aliases.any? { |part| @references.fetch(part.reference, 0) > 0 }
    return unless observed || (!branches && @characters.empty_first?(capture) && @characters.fixed_width(capture) != 0)
    scalar = facts.definitions.length == aliases.length && (!branches || aliases.one?)
    # The whole-iteration value also governs progress when nested regular
    # captures are never read. Their empty updates add no observable state to
    # the continuation; keep their slots in consuming iterations.
    scalar ||= !branches && @characters.regular?(capture) &&
      (facts.definitions - aliases.map(&:reference)).all? { |reference| @references.fetch(reference, 0).zero? }
    return unless facts.references.empty? &&
                  (scalar || (!branches && consuming_optional(capture)))

    if quantity.mode == :lazy
      ordered = @characters.empty_first?(capture) || @characters.regular?(capture)
      return unless !branches && scalar && ordered && consuming_inner_loops?(capture)
    end

    if branches
      # An empty-first capture followed by a skipping arm can revisit empty
      # updates in Ruby before testing the continuation. Progress-only cycles
      # do not represent that history; retain the explicit unsupported boundary.
      return unless greedy_sequence?(capture)

      skipped = branches.reject { |branch| branch.equal?(capture) }
      return unless skipped.all? { |branch| @characters.nonempty?(branch) }

      left = @characters.first(capture)
      sets = skipped.map { |branch| @characters.first(branch) }
      return unless left && sets.all? && left.case_insensitive.disjoint?(sets.reduce(:|).case_insensitive)
    end

    [capture, branches]
  end

  # A lazy loop tries its current continuation, then the body's preferred empty
  # update, then a consuming iteration. Repeated empty updates at one position
  # add no new outcomes when this capture covers the entire iteration. Every
  # consuming step overwrites it, so no empty value can move across skipped input.
  def lower(loop_expression, following)
    capture = Compiler.unwrap(loop_expression.children.first)
    lazy = loop_expression.quantity.mode == :lazy
    states = Compiler.capture_chain(capture).to_h { |part| [part.reference, true] }
    present_tail = Compiler::Specialize.call(following, states)
    optional = consuming_optional(capture) unless lazy
    prefix =
      if optional
        consuming = Expression.new(:capture, [optional], reference: capture.reference, nonempty: true)
        repetition(Expression.new(:group, [consuming]), '*')
      else
        consuming_iterations(capture, present_tail, lazy: lazy)
      end

    retained = Compiler.copy(following)
    if loop_expression.quantity.min > 0
      retained = Expression.new(:sequence, [value_check(capture.reference, true), retained])
    end
    guard = defer_empty(capture, present_tail) if lazy && !@characters.empty_first?(capture)
    Expression.new(:group, [prefix, endings(capture, present_tail, retained, lazy: lazy, guard: guard)])
  end

  def endings(capture, present_tail, retained, lazy: false, guard: nil)
    bindings = {}
    empty_capture = nil
    Compiler.capture_chain(capture).reverse_each do |part|
      reference = Compiler::Occurrence.new(part.reference.capture)
      bindings[part.reference] = reference
      empty_capture = Expression.new(:capture, empty_capture ? [empty_capture] : [], reference: reference, nullable: true)
    end
    empty_tail = Compiler.rebind(present_tail, bindings)
    empty_ending = Compiler::Continuation.new(empty_tail).branch(empty_capture)
    empty_ending = empty_ending.with(children: [guard, *empty_ending.children]) if guard

    branches = [empty_ending, Expression.new(:branch, [retained])]
    endings = Expression.new(:choice, lazy ? branches.reverse : branches)
    Expression.new(:group, [endings])
  end

  # A consuming-first body must exhaust successful consuming continuations
  # before taking its empty update. The native lazy prefix visits those paths
  # in order; this existence probe prevents its ending from accepting empty too
  # early. Every further step consumes input, so the probe needs no recursion.
  def defer_empty(capture, following)
    return defer_partial_empty(capture, following) unless @characters.empty_last?(capture)
    position = Compiler::Occurrence.new
    mark = Expression.new(:capture, ['[\\s\\S]*'], reference: position, nullable: true)
    progress = Expression.new(:negative_lookahead, [Expression.new(:value, [], reference: position)])
    consuming = consuming_capture(capture)
    tail = endings(capture, following, Compiler.copy(following), lazy: true)
    future = Expression.new(:sequence, [Expression.new(:lookahead, [mark]), repetition(consuming, '+'), progress, tail])
    Expression.new(:negative_lookahead, [Compiler.copy(future)])
  end

  # In a mixed body such as a*?b*, only b+ precedes the first empty path.
  # A successful future starting with that prefix must run before the empty
  # ending; a future starting with a belongs after it. Subsequent iterations
  # may use the complete body because this probe asks only about existence.
  def defer_partial_empty(capture, following)
    aliases = Compiler.capture_chain(capture)
    before = Compiler::BeforeEmpty.new(@characters).call(capture)
    return unless before
    first = aliases.reverse_each.reduce(before) do |body, part|
      Expression.new(:capture, [body], reference: part.reference, nonempty: true)
    end
    tail = endings(capture, following, Compiler.copy(following), lazy: true)
    future = Expression.new(:sequence, [Compiler.copy(first), repetition(consuming_capture(capture), '*'), tail])
    future = Compiler::CaptureHistories.call(future, aliases.map { |part| part.reference.capture })
    Expression.new(:negative_lookahead, [Compiler.copy(future)])
  rescue Compiler::BeforeEmpty::NotApplicable
    raise Compiler::Unsupported, 'unrecognized empty-path ordering in a lazy capture loop'
  end

  def lower_alternation(loop_expression, following, capture, branches)
    present_tail = Compiler::Specialize.call(following, capture.reference => true)
    # Only the capture branch can match empty, so the whole iteration's empty
    # value also represents that capture. The probe retains branch preference.
    probe_body = without_capture(loop_expression.children.first, capture.reference)
    probe = Expression.new(:capture, [probe_body], reference: capture.reference, nullable: true)
    consuming = Expression.new(:capture, capture.children, reference: capture.reference, nonempty: true)
    captured_step = consuming_iterations(consuming, present_tail, probe: probe, repeat: false)
    skipped = alternatives(branches.reject { |branch| branch.equal?(capture) })
    skipping_step = consuming_iterations(skipped, present_tail, probe: probe, repeat: false)
    skip = lambda { |text| repetition(Compiler.copy(skipping_step), text) }
    parts = if branches.first.equal?(capture)
              [repetition(Expression.new(:group, [skip.call('*?'), captured_step]), '+'), skip.call('*')]
            else
              [skip.call('*'), repetition(Expression.new(:group, [captured_step, skip.call('*')]), '+')]
            end
    prefix = alternatives([Expression.new(:group, parts), skip.call('*')])
    retained = Compiler.copy(following)
    if loop_expression.quantity.min > 0
      position = Compiler::Occurrence.new
      start = Expression.new(:capture, ['[\\s\\S]*'], reference: position, nullable: true)
      prefix = Expression.new(:group, [Expression.new(:lookahead, [start]), prefix])
      advanced = Expression.new(:negative_lookahead, [Expression.new(:value, [], reference: position)])
      retained = Expression.new(:group, [advanced, retained])
    end
    Expression.new(:group, [prefix, endings(capture, present_tail, retained)])
  end

  def consuming_iterations(capture, following, probe: capture, repeat: true, lazy: false)
    consuming = if capture.kind == :capture
                  consuming_capture(capture)
                else
                  capture
                end
    # A native star already rejects empty iterations. Lazy scalar loops can
    # use it directly because their explicit endings test the empty update
    # before the next consuming iteration; no position capture is needed.
    return repetition(consuming, '*?') if lazy

    position = Compiler::Occurrence.new
    mark = Expression.new(:capture, ['[\\s\\S]*'], reference: position, nullable: true)
    progress = Expression.new(:negative_lookahead, [Expression.new(:value, [], reference: position)])
    parts = [preferred_empty_ending(probe, following), Expression.new(:lookahead, [mark]), consuming, progress]
    body = Expression.new(:group, parts)
    repeat ? repetition(body, '*') : body
  end

  # JavaScript skips empty iterations even inside an uncaptured inner loop;
  # Ruby may stop there before trying a consuming alternative. Keep that
  # separate ordering problem out of a body emitted without further lowering.
  def consuming_inner_loops?(expression)
    return true if expression.instance_of?(String)

    if expression.kind == :repeat && (expression.quantity.max < 0 || expression.quantity.max > 1)
      body = Compiler.unwrap(expression.children.first)
      # ES2009 surrogate pairs arrive as a single passive fragment.
      body = body.children.first if body.kind == :opaque && body.children.one? && body.children.first.instance_of?(String)
      normalized = expression.quantity.mode == :lazy && expression.quantity.min.zero? && @characters.empty_first?(body)
      return false unless normalized || @characters.nonempty?(body)
    end

    expression.children.all? { |child| consuming_inner_loops?(child) }
  end

  # The body's first preferred match may be empty. If the continuation succeeds
  # with that value, forbid another consuming iteration at this position. Copy
  # the probe and continuation together so their captures cannot escape.
  def preferred_empty_ending(capture, following)
    reference = Compiler::Occurrence.new
    probe = Expression.new(:capture, capture.children, reference: reference, nullable: true)
    tail = Compiler.rebind(following, capture.reference => reference)
    test = Expression.new(:negative_lookahead,
                          [Expression.new(:lookahead, [probe]), value_check(reference, false), tail])
    Compiler.copy(test)
  end

  def value_check(reference, nonempty)
    value = Expression.new(:value, [], reference: reference)
    test = nonempty ? Expression.new(:negative_lookahead, [value]) : value
    Expression.new(:lookahead, ['[\\s\\S]*', '(?![\\s\\S])', test])
  end

  def repetition(body, text)
    quantity = Compiler::Quantity.from_text(text)
    Expression.new(:native_repeat, [body], quantity: quantity)
  end

  def consuming_capture(capture)
    captures = Compiler.capture_chain(capture)
    children = captures.last.children
    captures.reverse_each do |part|
      children = [Expression.new(:capture, children, reference: part.reference, nonempty: true)]
    end
    children.first
  end

  def alternatives(parts)
    Expression.new(:group, [Expression.new(:choice, parts.map { |part| Expression.new(:branch, [part]) })])
  end

  def without_capture(expression, reference)
    return expression if expression.instance_of?(String)
    return Expression.new(:group, expression.children) if expression.kind == :capture && expression.reference.equal?(reference)

    expression.with(children: expression.children.map { |child| without_capture(child, reference) })
  end

  def greedy_sequence?(expression)
    return true if expression.instance_of?(String)
    return false unless [:sequence, :group, :branch, :capture, :repeat].include?(expression.kind)
    return false if expression.quantity && expression.quantity.mode != :greedy

    expression.children.all? { |child| greedy_sequence?(child) }
  end

  # For ((a)?)*, consuming iterations necessarily update both groups. An empty
  # ending updates only the outer capture, leaving the inner value retained.
  # A greedy optional regular body prefers empty only when consumption fails.
  def consuming_optional(capture)
    return unless capture.children.one?

    optional = Compiler.unwrap(capture.children.first)
    return unless optional.kind == :repeat && optional.quantity.mode == :greedy &&
                  optional.quantity.min.zero? && optional.quantity.max == 1

    body = optional.children.first
    facts = @analysis[body]
    return unless @characters.nonempty?(body) && @characters.regular?(body)

    referenced = facts.definitions.select { |ref| @references.fetch(ref, 0) > 0 }
    body if referenced.all? { |ref| facts.must_capture.include?(ref) && @analysis.captures.fetch(ref).nonempty }
  end

  # When an empty update fails its continuation, Ruby may retain that empty
  # value through skipping iterations. A later empty update at a new position
  # then fails. Stopping probes are safe only if this cannot select an earlier
  # successful tail while a skipping branch could still consume.
  def safe_empty_tail?(capture, branches, following)
    return true if branches.last.equal?(capture)

    tail = replace_empty_value(Compiler::Specialize.call(following, capture.reference => true), capture.reference)
    analysis = Compiler::Analysis.new(tail)
    return true if analysis[tail].empty == :always || impossible?(tail, analysis) || empty_or_end(tail) == :end

    first = Compiler::CharacterFacts.new(analysis).first(tail)
    skipped = branches.reject { |branch| branch.equal?(capture) }.map { |branch| @characters.first(branch) }.reduce(:|)
    first && first.case_insensitive.disjoint?(skipped.case_insensitive)
  end

  def replace_empty_value(expression, reference)
    return expression if expression.instance_of?(String)

    if [:backreference, :value].include?(expression.kind) && expression.reference.equal?(reference)
      return Expression.new(:sequence)
    end

    expression.with(children: expression.children.map { |child| replace_empty_value(child, reference) })
  end

  def impossible?(expression, analysis)
    return false if expression.instance_of?(String)

    case expression.kind
    when :negative_lookahead then expression.children.all? { |child| analysis[child].empty == :always }
    when :sequence, :group, :branch, :capture then expression.children.any? { |child| impossible?(child, analysis) }
    when :choice then expression.children.all? { |child| impossible?(child, analysis) }
    end || false
  end

  def empty_or_end(expression)
    return STRING_PROPS[expression] if expression.instance_of?(String)
    return :empty if expression.kind == :repeat && expression.quantity.max.zero?
    return unless [:sequence, :group, :branch, :capture].include?(expression.kind)

    kinds = expression.children.map { |child| empty_or_end(child) }
    kinds.include?(:end) ? :end : :empty if kinds.all?
  end

  STRING_PROPS = { '' => :empty, '$' => :end }.freeze
end
