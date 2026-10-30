# frozen_string_literal: true

# Keep choices that can produce an empty capture beside their continuation.
# Moving them ahead of the whole pattern would change greedy/lazy match order.
class JsRegex::SecondPass::ExpandNullableCaptures < JsRegex::SecondPass
  def call
    loop do
      @counts = reference_counts(tree)
      break unless expand(tree)

      renumber_captures
    end
  end

  private

  def captures(node)
    result = []
    walk(node) { |part| result << part if part.type == :captured_group }
    result
  end

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
      next unless groups.any? { |capture| !capture.nonempty? && @counts[capture.reference] > 0 }

      following = Node.new(*node.children[(index + 1)...finish])
      suffix_counts = reference_counts(following)
      next unless groups.any? do |capture|
        !capture.nonempty? && @counts[capture.reference] > 0 &&
          suffix_counts[capture.reference] == @counts[capture.reference]
      end

      replacement = expand_choice(child, following, groups)
      next unless replacement

      node.update(children: [*node.children[0...index], replacement, *node.children[finish..-1]])
      return true
    end
    false
  end

  def expand_choice(child, following, groups)
    if child.type == :captured_group && child.nullable? && child.quantifier && child.quantifier.max < 0 &&
        child.quantifier.min <= 1 && !child.quantifier.reluctant? && groups.length == 1
      return expand_nullable_loop(child, following)
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

  def passive_sequence?(node)
    return false unless node.type == :plain && !node.quantifier && node.children.any? { |child| child.is_a?(Node) }

    node.children.first == '(?:' || !node.children.any? { |child| child.is_a?(String) }
  end

  def choices_for(node)
    if node.optional? && node.quantifier.max == 1
      present = node.clone.update(quantifier: nil)
      absent = node.clone
      null_quantify(absent)
      node.quantifier.reluctant? ? [absent, present] : [present, absent]
    elsif !node.quantifier
      split_alternatives(node)
    end
  end

  def expand_nullable_loop(capture, following)
    present_tail = following.clone
    specialize(present_tail, capture.reference => true)
    prefix = nonempty_iterations(capture, present_tail)
    empty_capture = capture.copy_with_children('(', ')').update(quantifier: nil)
    ending = alternate([
      Node.new(empty_capture, present_tail),
      last_nonempty_tail(capture, following),
    ])
    Node.new(prefix, ending)
  end

  def nonempty_iterations(capture, present_tail)
    stop = stop_before_empty_capture(capture, present_tail)
    remainder = temporary_capture('[\\s\\S]*')
    participating = Node.new(*capture.children.map(&:clone), type: :captured_group,
                             reference: capture.reference, nonempty: true)
    prefix = Node.new('(?:', stop, Node.new('(?=', remainder, ')'), participating,
                      require_progress(remainder.reference), ')')
    prefix.update(quantifier: Regexp::Expression::Quantifier.construct(text: '*'))
  end

  def stop_before_empty_capture(capture, following)
    # Prefer Ruby's final empty iteration when the body first chooses empty
    # and the rest of the pattern succeeds with that value.
    probe = temporary_capture(*capture.children[1...-1].map(&:clone))
    tail = following.clone
    walk(tail) do |part|
      next unless part.reference == capture.reference && part.type != :captured_group

      part.update(reference: probe.reference)
      part.update(children: ["\\#{probe.reference}"]) if [:backref, :capture_check].include?(part.type)
    end
    Node.new('(?!', Node.new('(?=', probe, ')'), nonempty_capture_check(probe.reference, false), tail, ')')
  end

  def last_nonempty_tail(capture, following)
    tail = following.clone
    walk(tail) do |part|
      make_condition_dynamic(part) if part.type == :conditional && part.reference == capture.reference
    end
    capture.optional? ? tail : Node.new(nonempty_capture_check(capture.reference, true), tail)
  end

  def split_alternatives(node)
    if alternation?(node)
      node.children.map do |branch|
        chosen = branch.clone.update(type: :plain)
        chosen.children.shift if chosen.children.first == '|'
        chosen
      end
    else
      grouped = ['(', '(?:'].include?(node.children.first) && node.children.last == ')'
      return unless grouped || node.children.length == 1

      children = node.children.grep(Node)
      return unless children.length == 1 && !children.first.quantifier

      alternatives = split_alternatives(children.first)
      return unless alternatives

      alternatives.map do |alternative|
        node.copy_with_children(*node.children.map { |child| child.equal?(children.first) ? alternative : child.clone })
      end
    end
  end

  def capture_states(node, original_groups)
    found = captures(node).map(&:reference)
    states = (original_groups - found).map { |reference| [reference, false] }.to_h
    collect_states(node, states)
    states
  end

  def collect_states(node, states, required = true, excluded = false)
    return unless node.is_a?(Node)

    excluded ||= node.quantifier && node.quantifier.max.zero?
    required &&= !node.optional? && !['(?!', '(?<!'].include?(node.children.first)
    if node.type == :captured_group
      states[node.reference] = false if excluded
      states[node.reference] = true if required && !excluded
    end
    required &&= ![:conditional, :capture_conditional].include?(node.type) &&
      !node.children.all? { |child| branch?(child) }
    node.children.each { |child| collect_states(child, states, required, excluded) }
  end

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
      if states.key?(node.reference)
        branches = node.children[1...-1]
        selected = states[node.reference] ? branches[0] : branches[1] || Node.new
        node.update(type: :plain, reference: nil, children: ['(?:', selected, ')'])
      end
    when :capture_conditional
      references = node.children.first.children.map(&:reference)
      present = references.any? { |reference| states[reference] }
      if present || references.all? { |reference| states[reference] == false }
        selected = present ? node.children[1] : node.children[2] || Node.new
        node.update(type: :plain, children: ['(?:', selected, ')'])
      end
    end
    node.children.each { |child| specialize(child, states) }
  end
end
