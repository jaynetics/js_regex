# frozen_string_literal: true

# Separate choices that skip a capture from choices that capture an empty string.
# Copy the rest of the pattern into each choice so references and conditionals
# use that choice's capture state without changing greedy or lazy match order.
# For nullable loops, keep the final empty capture outside the repeated body.
# Example: /(a*)?\1/ => /(?:(a*)\1|(a*){0}(?!))/.
# The absent choice fails; the present choice may still capture an empty string.
class JsRegex::SecondPass::ExpandNullableCaptures < JsRegex::SecondPass
  def call
    return unless any_node? { |node| node.type == :captured_group && !node.nonempty? }

    loop do
      @counts = reference_counts(tree)
      break if @counts.empty? || !expand(tree)

      renumber_captures
    end
  end

  private

  # /(a)(?:b(c))/ => the capture nodes numbered [1, 2].
  def captures(node)
    result = []
    walk(node) { |part| result << part if part.type == :captured_group }
    result
  end

  # In /b(a*)?\1c/, replace /(a*)?\1c/ together, so each choice gets its
  # own continuation; return true after that one replacement.
  def expand(node, repeated = false)
    return false unless node.is_a?(Node)

    repeated ||= repeated?(node)
    return true if node.children.any? { |child| expand(child, repeated) }
    return false if repeated

    # Compound atomic wrappers cannot be treated as ordinary sequences.
    finish = sequence_end(node)
    return false unless finish

    node.children.each.with_index do |child, index|
      next unless child.is_a?(Node)

      groups = captures(child)
      candidates = groups.reject { |capture| capture.nonempty? || @counts[capture.reference].zero? }
      next if candidates.empty?

      following = Node.new(*node.children[(index + 1)...finish])
      suffix_counts = reference_counts(following)
      next unless candidates.any? { |capture| suffix_counts[capture.reference] == @counts[capture.reference] }

      replacement = expand_choice(child, following, groups)
      next unless replacement

      node.update(children: [*node.children[0...index], replacement, *node.children[finish..-1]])
      return true
    end
    false
  end

  # For /(?:(a*)?)\1/, move the continuation into the passive group:
  # /(?:(a*)?\1)/, allowing a subsequent expansion of the inner optional capture.
  def expand_choice(child, following, groups)
    if groups.length == 1
      if greedy_nullable_loop?(child)
        return expand_nullable_loop(child, following)
      elsif child.quantifier&.reluctant?
        collapsed = collapse_lazy_character_run(child, following)
        return collapsed if collapsed
      end
    end

    if child.quantifier && child.quantifier.max < 0 && child.quantifier.min <= 1 && !child.quantifier.reluctant?
      replacement = expand_nullable_alternation(child, following, groups)
      return replacement if replacement
    end

    choices = choices_for(child)
    if choices
      original_groups = groups.map(&:reference)
      alternate(choices.map do |choice|
        continuation = following.clone
        specialize(continuation, capture_states(choice, original_groups))
        Node.new(choice, continuation, type: :branch)
      end)
    elsif passive_sequence?(child)
      position = child.children.first == '(?:' ? child.children.length - 1 : child.children.length
      child.children.insert(position, *following.children)
      child
    end
  end

  # /(a*)+?\1/ => /a*()/: the greedy run first consumes every a. Its reference
  # then fails unless the run was empty, so Ruby takes one final empty iteration.
  # Restrict this to a single-character run and a lone required reference;
  # a longer continuation can force backtracking to a different capture value.
  def collapse_lazy_character_run(capture, following)
    quantity = capture.quantifier
    return unless capture.type == :captured_group && quantity && quantity.reluctant? &&
      quantity.max < 0 && quantity.min <= 1

    reference = following.children.first
    return unless following.children.one? && reference.is_a?(Node) && reference.type == :backref &&
      reference.reference == capture.reference && !reference.quantifier

    body = Node.new(*capture.children[1...-1])
    expression = single_expression(Regexp::Parser.parse(body.to_s))
    repeat = expression.quantifier
    return unless repeat && repeat.min.zero? && repeat.max < 0 && !repeat.reluctant?

    expression.quantifier = nil
    expression = single_expression(expression)
    return unless [:literal, :set, :type, :property, :nonproperty, :escape].include?(expression.type) &&
      expression.match_length.fixed? && expression.match_length.min == 1

    Node.new(body, empty_capture(capture))
  rescue Regexp::Parser::Error, Node::TypeError
    nil
  end

  # /(?:a)/ => the a expression; /(?:ab)*/ stays wrapped because it is quantified.
  def single_expression(expression)
    while !expression.quantifier && [:group, :expression].include?(expression.type) && expression.expressions.one?
      expression = expression.expressions.first
    end
    expression
  end

  # A nullable alternative can end the loop before a later, consuming
  # alternative is tried. Test that stopping choice before each nonempty step.
  # For /(?:(a*)|b)+\1/ on 'b', try the final empty capture before consuming b.
  # Shape: guarded nonempty iterations, then /()\1/ or a retained-capture tail.
  def expand_nullable_alternation(loop_node, following, groups)
    referenced = groups.select { |group| @counts[group.reference] > 0 }
    return unless referenced.length == 1 && referenced.first.nullable?
    return unless reference_counts(loop_node).empty?

    capture = referenced.first
    iteration = loop_node.clone.update(quantifier: nil)
    choices = split_alternatives(iteration)
    return unless choices && choices.length > 1
    empty_choices = choices.select { |choice| captures(choice).any? { |group| group.reference == capture.reference } }
    return unless empty_choices.length == 1 && capture_only?(empty_choices.first, capture.reference)
    return unless (choices - empty_choices).all? { |choice| Regexp::Parser.parse(choice.to_s).match_length.min > 0 }

    present_tail = following.clone
    specialize(present_tail, capture.reference => true)
    probe_body = Node.new('(', iteration.clone, ')', reference: capture.reference)
    stop = stop_before_empty_capture(probe_body, present_tail)
    position = temporary_capture('[\\s\\S]*')
    mark_nonempty_capture(iteration, capture.reference)
    prefix = Node.new('(?:', stop, Node.new('(?=', position, ')'), iteration,
                      require_progress(position.reference), ')')
    prefix.update(quantifier: Regexp::Expression::Quantifier.construct(text: '*'))

    empty = empty_choices.first
    walk(empty) do |part|
      part.update(children: ['(', ')'], quantifier: nil) if part.type == :captured_group && part.reference == capture.reference
    end
    retained_tail = following.clone
    walk(retained_tail) do |part|
      make_condition_dynamic(part) if part.type == :conditional && part.reference == capture.reference
    end
    unless loop_node.optional?
      start = temporary_capture('[\\s\\S]*')
      prefix = Node.new(Node.new('(?=', start, ')'), prefix)
      retained_tail = Node.new(require_progress(start.reference), retained_tail)
    end
    Node.new(prefix, alternate([Node.new(empty, present_tail), retained_tail]))
  rescue Regexp::Parser::Error, Node::TypeError
    nil
  end

  # For capture 1, /(?:(a*))/ => true; /(?:b(a*))/ => false.
  def capture_only?(node, reference)
    return ['(', '(?:', ')', ''].include?(node) if node.instance_of?(String)
    return !node.quantifier if node.type == :captured_group && node.reference == reference
    return false if node.quantifier

    node.children.all? { |child| capture_only?(child, reference) }
  end

  # Inside a guarded consuming iteration, (a*) keeps its source but changes
  # its nonempty annotation from false to true.
  def mark_nonempty_capture(node, reference)
    node.children.map! do |child|
      next child if child.instance_of?(String)

      if child.type == :captured_group && child.reference == reference
        Node.new(*child.children, reference: reference, type: :captured_group, nonempty: true)
          .update(quantifier: child.quantifier)
      else
        mark_nonempty_capture(child, reference)
        child
      end
    end
  end

  # /(a*)+/ => true; /(a*)+?/ => false.
  def greedy_nullable_loop?(node)
    node.type == :captured_group && node.nullable? && node.quantifier &&
      node.quantifier.max < 0 && node.quantifier.min <= 1 && !node.quantifier.reluctant?
  end

  # /(?:a(b))/ => true; /(?:a(b))*/ => false because it is repeated.
  def passive_sequence?(node)
    return false unless node.type == :plain && !node.quantifier && node.children.any? { |child| child.is_a?(Node) }

    node.children.first == '(?:' || !node.children.any? { |child| child.instance_of?(String) }
  end

  # /(a*)?/ => [/(a*)/, /(a*){0}/]; /(a*)??/ gives the reverse order.
  def choices_for(node)
    if node.optional? && node.quantifier.max == 1
      present = node.clone.update(quantifier: nil)
      absent = node.clone
      discard_contents(absent)
      node.quantifier.reluctant? ? [absent, present] : [present, absent]
    elsif !node.quantifier
      split_alternatives(node)
    end
  end

  # Shape: /(a*)+\1/ => guarded nonempty iterations followed by either
  # /()\1/ or /\1/ using the last nonempty capture. The empty ending is tried first.
  def expand_nullable_loop(capture, following)
    present_tail = following.clone
    specialize(present_tail, capture.reference => true)
    prefix = nonempty_iterations(capture, present_tail)
    ending = alternate([
      Node.new(empty_capture(capture), present_tail),
      last_nonempty_tail(capture, following),
    ])
    Node.new(prefix, ending)
  end

  # For the repeated body (a*), consuming 'aaa' is allowed; consuming '' is
  # blocked by a position check and left to the separate empty ending.
  def nonempty_iterations(capture, present_tail)
    stop = stop_before_empty_capture(capture, present_tail)
    remainder = temporary_capture('[\\s\\S]*')
    participating = Node.new(*capture.children.map(&:clone), type: :captured_group,
                             reference: capture.reference, nonempty: true)
    prefix = Node.new('(?:', stop, Node.new('(?=', remainder, ')'), participating,
                      require_progress(remainder.reference), ')')
    prefix.update(quantifier: Regexp::Expression::Quantifier.construct(text: '*'))
  end

  # With capture /(a*)/ and tail /\1b/, input 'b' selects the empty ending;
  # the emitted negative lookahead prevents another loop iteration there.
  def stop_before_empty_capture(capture, following)
    # Prefer Ruby's final empty iteration when the body first chooses empty
    # and the rest of the pattern succeeds with that value.
    probe = temporary_capture(*capture.children[1...-1].map(&:clone))
    tail = following.clone
    walk(tail) do |part|
      next unless part.reference == capture.reference && part.type != :captured_group

      part.renumber(probe.reference)
    end
    Node.new('(?!', Node.new('(?=', probe, ')'), nonempty_capture_check(probe.reference, false), tail, ')')
  end

  # For /(a*)+/ followed by /\1/, emit /(?=[\s\S]*(?![\s\S])(?!\1))\1/,
  # so this ending requires a previous nonempty capture.
  def last_nonempty_tail(capture, following)
    tail = following.clone
    walk(tail) do |part|
      make_condition_dynamic(part) if part.type == :conditional && part.reference == capture.reference
    end
    capture.optional? ? tail : Node.new(nonempty_capture_check(capture.reference, true), tail)
  end

  # Choice /(a*)/ from /(?:(a*)|(b*))/ => {1 => true, 2 => false}.
  def capture_states(node, original_groups)
    found = captures(node).map(&:reference)
    states = (original_groups - found).to_h { |ref| [ref, false] }
    collect_states(node, states)
    states
  end

  # /(a*)(b*)?(c*){0}/ => {1 => true, 3 => false}; capture 2 stays unknown.
  def collect_states(node, states, required = true, excluded = false)
    return unless node.is_a?(Node)

    excluded ||= node.quantifier && node.quantifier.max.zero?
    required &&= !node.optional? && !node.negative_assertion?
    if node.type == :captured_group
      states[node.reference] = false if excluded
      states[node.reference] = true if required && !excluded
    end
    required &&= ![:conditional, :capture_conditional].include?(node.type) &&
      !node.children.all? { |child| branch?(child) }
    node.children.each { |child| collect_states(child, states, required, excluded) }
  end

  # With {1 => false}, \1 => /(?!)/ and (?(1)a|b) selects b.
  # With {1 => true}, the same condition selects a, even for an empty capture.
  def specialize(node, states)
    return unless node.is_a?(Node)

    case node.type
    when :backref
      node.update(type: :plain, reference: nil, children: ['(?!)']) if states[node.reference] == false
    when :multiplex_backref, :capture_backref
      children = node.children.reject { |child| states[child.reference] == false }
      if children.empty?
        node.update(type: :plain, reference: nil, children: ['(?!)'])
      else
        node.update(children: children)
      end
    when :conditional
      select_conditional_branch(node, states[node.reference]) if states.key?(node.reference)
    when :capture_conditional
      references = node.children.first.children.map(&:reference)
      present = references.any? { |reference| states[reference] }
      if present || references.all? { |reference| states[reference] == false }
        select_conditional_branch(node, present)
      end
    end
    node.children.each { |child| specialize(child, states) }
  end
end
