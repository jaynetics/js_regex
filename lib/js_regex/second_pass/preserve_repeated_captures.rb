# frozen_string_literal: true

# Rewrite unbounded repetitions so captures survive later iterations that skip
# their groups, as in Ruby. Isolate the last capturing iteration, or group each
# capturing iteration with the intervening iterations that skip the group.
# Example shape: /(?:(a)|b)+\1/ => /(?:b*?(a))+b*\1/.
# This shows the successful capturing path, omitting disabled branches and the
# separate path with no capture, whose required backreference will fail.
class JsRegex::SecondPass::PreserveRepeatedCaptures < JsRegex::SecondPass
  def call
    collect_references
    return if @references.empty?

    while @references.uniq.length > 1 && expand_lazy_capture_loops(tree)
      renumber_captures
      collect_references
    end
    rewrite_repetitions(tree)
    renumber_captures if @rewritten
  end

  private

  # /(a)\1/ => references [1], mandatory references [1]; /(a)\1?/ keeps
  # reference 1 but does not mark it mandatory.
  def collect_references
    @references = []
    @groups = {}
    group_paths = {}
    reference_paths = []
    path = []
    walk(trace: true) do |node, event|
      if event == :exit
        path.pop
        next
      end
      if node.type == :captured_group
        @groups[node.reference] = node
        group_paths[node.reference] = [*path, node]
      elsif node.reference
        @references << node.reference
      end
      if node.type == :backref && path.none? { |ancestor| [:multiplex_backref, :capture_backref].include?(ancestor.type) }
        reference_paths << [node.reference, [*path, node]]
      end
      path.push(node)
    end
    # A reference can be required within its own branch or optional parent,
    # even when that entire scope can be skipped by the rest of the pattern.
    @mandatory_references = reference_paths.select do |reference, reference_path|
      required_on_path?(reference_path, group_paths[reference] || [])
    end.map(&:first)
  end

  # /(?:(a)|b)/ => [1]; after disabling b with a generated (?!) node,
  # /(?:(a)|b(?!))/ => [] since only the capturing branch can match.
  def skipped_captures(node = tree, optional = false)
    return [] if node.is_a?(String) || unmatchable?(node)

    optional ||= node.optional? || node.type == :conditional || node.negative_assertion?
    children = node.children
    if alternation?(node)
      children = children.reject { |child| unmatchable?(child) }
      optional ||= children.length > 1
    end
    groups = optional && node.type == :captured_group ? [node.reference] : []
    children.each { |child| groups.concat(skipped_captures(child, optional)) }
    groups
  end

  # For /(?:(a)|b)+\1/, choose capture-update cycles; for {2}, leave the loop
  # to ExpandBoundedCaptureLoops.
  def rewrite_repetitions(node)
    return unless node.is_a?(Node)

    node.children.each { |child| rewrite_repetitions(child) }
    quantifier = node.quantifier
    return unless quantifier&.max&.<(0)

    iteration = node.clone.update(quantifier: nil)
    plan = nil
    reference = skipped_captures(iteration).find do |number|
      @references.include?(number) && (@groups[number].nonempty? || @groups[number].nullable?) &&
        (plan = rewrite_plan(iteration, number, quantifier))
    end
    return unless reference

    kind, capture_first = plan
    if kind == :last
      isolate_last_capture(node, iteration, reference, quantifier)
    else
      repeat_capture_updates(node, iteration, reference, quantifier,
                             capture_first: capture_first, internal: kind == :retained)
    end
    @rewritten = true
    rewrite_repetitions(node)
  end

  # In /x(?:(a+)|(b+))+?\1\2y/, replace the loop together with /\1\2y/,
  # so its ending can test the continuation before choosing iteration boundaries.
  def expand_lazy_capture_loops(node)
    return false unless node.is_a?(Node)
    return false if repeated?(node)

    finish = sequence_end(node)
    if finish
      node.children.each.with_index do |child, index|
        next unless child.is_a?(Node) && child.quantifier && child.quantifier.max < 0 &&
          child.quantifier.min <= 1 && child.quantifier.reluctant?

        following = Node.new(*node.children[(index + 1)...finish])
        replacement = lazy_capture_loop(child, following)
        next unless replacement

        node.update(children: [*node.children[0...index], replacement, *node.children[finish..-1]])
        return true
      end
    end
    node.children.any? { |child| expand_lazy_capture_loops(child) }
  end

  # Shape for /(?:(a+)|(b+))+?\1\2/: optional b-run, repeated a/b run pairs,
  # then guarded endings. Each run retains its last capture for the continuation.
  def lazy_capture_loop(node, following)
    alternatives = alternating_capture_runs(node, following)
    return unless alternatives

    left, right = alternatives.map { |part| Node.new(lazy_run(without_captures(part), 0), part) }
    pair = Node.new(left.clone, right.clone)
    ending = lazy_loop_endings(alternatives.first, left, right, pair, following)
    prefix = Node.new('(?:', right, ')').update(quantifier: quantity(0, 1, true))
    Node.new(prefix, lazy_run(pair, 0), ending)
  rescue Regexp::Parser::Error, CharacterSet::ExpressionConverter::Error, Node::TypeError
    nil
  end

  # /(?:(a+)|(b+))+?\2\1/ => [/(b+)/, /(a+)/], ordered by the following refs.
  def alternating_capture_runs(node, following)
    return unless reference_counts(node).empty?

    iteration = node.clone.update(quantifier: nil)
    alternatives = split_alternatives(iteration)
    return unless alternatives && alternatives.length == 2

    references = alternatives.map { |alternative| referenced_run(alternative) }
    return unless references.all? && references.uniq.length == 2
    first, second = following.children
    return unless [first, second].all? { |part| part.is_a?(Node) && part.type == :backref && !part.quantifier }
    return unless [first.reference, second.reference].sort == references.sort
    counts = reference_counts(following)
    return unless references.all? { |reference| counts[reference] == 1 && @references.count(reference) == 1 }

    alternatives.reverse! if first.reference != references.first
    expressions = alternatives.map { |part| Regexp::Parser.parse(part.to_s) }
    alternatives if disjoint_starts?(*expressions)
  end

  # An alternative /(a+)/ with capture 1 referenced => 1; /(ab+)/ => nil,
  # since it is not a run of a single character.
  def referenced_run(alternative)
    groups = []
    walk(alternative) do |part|
      groups << part if part.type == :captured_group && @references.include?(part.reference)
    end
    return unless groups.length == 1 && groups.first.nonempty?
    return if potentially_absent_groups(alternative).include?(groups.first.reference)

    groups.first.reference if capture_run?(alternative, groups.first)
  end

  # For /(?:(a+)|(b+))+?\1\2/, endings try the tail, one final a capture,
  # then a split a-run; probes prevent these from outranking an earlier iteration.
  def lazy_loop_endings(first, left, right, pair, following)
    continuation = Node.new(right.clone, lazy_run(pair.clone, 0), alternate([
      following.clone, Node.new(left.clone, following.clone),
    ]))
    raw_future = Node.new(first.clone, continuation.clone)
    discarded = without_captures(first)

    # A final first-character run has two stopping choices: shorten its first
    # iteration, or make another iteration. Prefer any successful continuation
    # from an earlier (longer) first iteration before accepting either choice.
    single_probe = Node.new('(?=', first.clone, following.clone, ')')
    shorter = Node.new(discarded.clone, Node.new('(?!', capture_value(following.children.first.reference), ')'),
                       first.clone, continuation.clone)
    single_tail = Node.new(single_probe, Node.new('(?!', alternate([raw_future.clone, shorter]), ')'),
                           first.clone, following.clone)

    discarded_prefix = temporary_capture(discarded.clone)
    split_probe = Node.new('(?=', discarded_prefix, first.clone, following.clone, ')')
    earlier = Node.new(capture_value(discarded_prefix.reference), lazy_run(discarded, 0),
                       first.clone, continuation)
    split_tail = Node.new(split_probe, Node.new('(?!', alternate([raw_future, earlier]), ')'),
                          backref(discarded_prefix.reference), first.clone, following.clone)
    alternate([following.clone, single_tail, split_tail])
  end

  # /(a(b))/ => /(?:a(?:b))/.
  def without_captures(node)
    copy = node.clone
    walk(copy) do |part|
      next unless part.type == :captured_group

      part.update(type: :plain, reference: nil, children: ['(?:', *part.children[1..-1]])
    end
    copy
  end

  # Restrict this rewrite to greedy runs of one character, with the capture
  # covering the entire alternative. Splitting more general words can change
  # the order in which a loop explores its iteration boundaries.
  # /(a+)/ => true; /(a+?)/ => false; /(ab+)/ => nil (also ineligible).
  def capture_run?(node, capture)
    return ['(', '(?:', ')', ''].include?(node) if node.is_a?(String)
    if node.equal?(capture)
      return false if node.quantifier || any_node?(node) { |part| part.quantifier && part.quantifier.reluctant? }

      expression = Regexp::Parser.parse(node.children.join)
      while !expression.terminal? && !expression.quantifier && expression.expressions.length == 1
        expression = expression.expressions.first
      end
      quantifier = expression.quantifier
      return quantifier && quantifier.min == 1 && quantifier.max < 0 &&
        !quantifier.reluctant? && expression.match_length.min == 1 && CharacterSet.of_expression(expression).size == 1
    end
    return false if node.quantifier

    node.children.all? { |child| capture_run?(child, capture) }
  end

  # (/a/, 0) => /(?:a){0,}?/; (/a/, 1) => /(?:a){1,}?/.
  def lazy_run(node, minimum)
    Node.new('(?:', node, ')').update(quantifier: quantity(minimum, -1, true))
  end

  # Capturing-path shape: /(?:(a)|b)+/ => /(?:a|b)*(a)b*/.
  # Earlier (a) copies become passive; the final copy survives all later b's.
  def isolate_last_capture(node, iteration, reference, quantifier)
    absent = iteration.clone
    remove_capture(absent, reference, exclude: true)
    absent.update(quantifier: quantifier)
    branches = prefix_counts(quantifier).map do |prefix_min, prefix_max|
      prefix = iteration.clone
      remove_capture(prefix, reference, exclude: false)
      prefix.update(quantifier: quantity(prefix_min, prefix_max, quantifier.reluctant?))
      last_update = iteration.clone
      require_group_participation(last_update, reference)
      suffix = iteration.clone
      remove_capture(suffix, reference, exclude: true)
      suffix_min = [quantifier.min - prefix_min - 1, 0].max
      suffix.update(quantifier: quantity(suffix_min, -1, quantifier.reluctant?))
      Node.new(prefix, last_update, suffix)
    end
    replace_loop(node, branches, absent, quantifier.reluctant?)
  end

  # {3,} => [[2, -1], [1, 1], [0, 0]]; {3,}? reverses that order.
  # -1 means unbounded; the final capture and suffix fill the remaining minimum.
  def prefix_counts(quantifier)
    minimum = [quantifier.min - 1, 0].max
    counts = (0...minimum).map { |count| [count, count] } + [[minimum, -1]]
    quantifier.reluctant? ? counts : counts.reverse
  end

  # For the loop in /(?:(a)|b)+\1/, return [:cycles, true]: each cycle updates
  # capture 1, and its alternative is tried before the skipping alternative.
  def rewrite_plan(iteration, reference, quantifier)
    target = nil
    internal_reference = false
    other_capture = false
    walk(iteration) do |node|
      target = node if node.type == :captured_group && node.reference == reference
      other_capture ||= node.type == :captured_group && node.reference != reference && @references.include?(node.reference)
      internal_reference ||= [:backref, :capture_backref, :conditional, :capture_conditional].include?(node.type)
    end
    capturing = iteration.clone
    require_group_participation(capturing, reference)
    skipping = iteration.clone
    remove_capture(skipping, reference, exclude: true)
    captured_expression = Regexp::Parser.parse(analysis_source(capturing))
    skipped_expression = Regexp::Parser.parse(analysis_source(skipping))
    mandatory = @mandatory_references.include?(reference)
    single_capture = (skipped_captures(iteration) & @references).uniq.length == 1
    if !internal_reference && !other_capture && single_capture && target.nonempty? && quantifier.min <= 1 &&
        captured_expression.match_length.min > 0 && skipped_expression.match_length.min > 0
      first = capture_at_edge?(iteration, reference, first: true)
      last = capture_at_edge?(iteration, reference, first: false)
      if (first && !quantifier.reluctant?) || (mandatory && (first || last))
        return [:cycles, first]
      end
    end

    disjoint = disjoint_starts?(captured_expression, skipped_expression)
    capture = Regexp::Parser.parse(target.children.join)
    empty_capture_safe = target.nullable? && disjoint && !quantifier.reluctant?
    single_character_run = target.nonempty? && CharacterSet.of_expression(capture).size == 1 && !quantifier.reluctant?
    if !internal_reference && (capture.match_length.fixed? || empty_capture_safe || single_character_run) &&
        (disjoint || (single_capture && mandatory && !quantifier.reluctant?))
      [:last, nil]
    elsif (disjoint || (single_capture && mandatory && quantifier.reluctant?)) &&
        quantifier.min <= 1 && skipped_expression.match_length.min > 0
      [:retained, nil]
    end
  rescue Regexp::Parser::Error, CharacterSet::ExpressionConverter::Error, Node::TypeError
    nil
  end

  # /a+/ and /b+/ => true; /a/ and /A/ => false after case folding.
  def disjoint_starts?(left, right)
    left_characters = first_characters(left).case_insensitive
    right_characters = first_characters(right).case_insensitive
    left_characters.disjoint?(right_characters)
  end

  # Whether branch and optional choices try the capture first or last.
  # In /(?:(a)|b)/, capture 1 is first: true, last: false;
  # /(?:(a)??)/ is first: false, last: true because skipping is tried first.
  def capture_at_edge?(node, reference, first:)
    return false if node.is_a?(String)
    return false if node.optional? && node.quantifier.reluctant? == first
    return true if node.type == :captured_group && node.reference == reference

    if alternation?(node)
      capture_at_edge?(first ? node.children.first : node.children.last, reference, first: first)
    else
      node.children.any? { |child| capture_at_edge?(child, reference, first: first) }
    end
  end

  # Capturing-path shape: /(?:(a)|b)+/ => /(?:b*?(a))+b*/.
  # Every repeated cycle contains (a), so trailing b iterations cannot clear it.
  def repeat_capture_updates(node, iteration, reference, quantifier, capture_first:, internal:)
    skipping = iteration.clone
    remove_capture(skipping, reference, exclude: true)
    prefix = skipping.clone.update(quantifier: quantity(0, -1, internal ? quantifier.reluctant? : capture_first))
    update = iteration.clone
    require_group_participation(update, reference)
    suffix = skipping.clone.update(quantifier: quantity(0, -1, quantifier.reluctant?))
    # Put skips before or after each update according to the original branch
    # order. Every successful cycle includes the capture, so JS retains it.
    ends_with_capture = !internal && capture_first != quantifier.reluctant?
    cycle = ends_with_capture ? Node.new('(?:', prefix, update, ')') : Node.new('(?:', update, suffix, ')')
    cycle.update(quantifier: quantity(1, -1, quantifier.reluctant?))
    present = ends_with_capture ? Node.new(cycle, suffix) : Node.new(prefix, cycle)
    absent = skipping.update(quantifier: quantifier)
    replace_loop(node, [present], absent, quantifier.reluctant?)
    walk(node) do |child|
      make_condition_dynamic(child) if child.type == :conditional && child.reference == reference
    end
  end

  # Present [/a/], absent /b/: greedy => /(?:a|b)/; lazy => /(?:b|a)/.
  def replace_loop(node, present_branches, absent, reluctant)
    branches = reluctant ? [absent, *present_branches] : [*present_branches, absent]
    node.update(type: :plain, reference: nil, quantifier: nil, children: [alternate(branches)])
  end

  # \1 => /(?:[\s\S]*)/ for conservative length/character analysis only;
  # this approximation is not emitted as the converted regexp.
  def analysis_source(node)
    return node if node.is_a?(String)

    source = case node.type
             when :backref, :capture_backref, :multiplex_backref
               '(?:[\s\S]*)'
             when :conditional
               '(?:' + node.children[1...-1].map { |child| analysis_source(child) }.join('|') + ')'
             when :capture_conditional
               '(?:' + node.children[1..-1].map { |child| analysis_source(child) }.join('|') + ')'
             else
               if alternation?(node)
                 branches = node.children.reject { |child| unmatchable?(child) }
                 '(?:' + branches.map { |child| analysis_source(child).sub(/\A\|/, '') }.join('|') + ')'
               else
                 node.children.map { |child| analysis_source(child) }.join
               end
             end
    source + node.quantifier.to_s
  end

  # /a?b/ => {'a', 'b'}; /^b/ => {'b'} since the anchor consumes nothing.
  def first_characters(expression)
    return CharacterSet.new if expression.quantifier && expression.quantifier.max.zero?

    case expression.type
    when :literal
      CharacterSet.of_string(expression.text[0].to_s)
    when :assertion, :anchor
      CharacterSet.new
    when :group, :expression
      result = nil
      expression.expressions.each do |child|
        characters = first_characters(child)
        unless characters.empty?
          result = result ? result | characters : characters
        end
        break unless child.match_length.min.zero?
      end
      result || CharacterSet.new
    when :meta
      if expression.token == :dot
        CharacterSet.unicode
      else
        expression.expressions.map { |child| first_characters(child) }.reject(&:empty?).reduce(:|) || CharacterSet.new
      end
    else
      CharacterSet.of_expression(expression)
    end
  end

  # (1, -1, true) => {1,}?; (0, 2, false) => {0,2}.
  def quantity(minimum, maximum, reluctant)
    maximum = '' if maximum < 0
    Regexp::Expression::Quantifier.construct(text: "{#{minimum},#{maximum}}#{'?' if reluctant}")
  end

  # For capture 1, (a) => (?:a) with exclude: false; with exclude: true,
  # (a) => (?!) and (a)? => an empty sequence.
  def remove_capture(node, reference, exclude:)
    return unless node.is_a?(Node)

    if node.type == :captured_group && node.reference == reference
      if exclude
        node.update(type: :plain, reference: nil, children: [node.optional? ? '' : '(?!)'], quantifier: nil)
      else
        node.update(type: :plain, reference: nil, children: ['(?:', *node.children[1..-1]])
      end
    else
      node.children.each { |child| remove_capture(child, reference, exclude: exclude) }
    end
  end
end
