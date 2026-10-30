# frozen_string_literal: true

# Rewrite unbounded loops whose backreferences can be replaced by fixed strings.
# Track which captures have participated, then substitute their known values
# in backreferences and select conditional branches in the original choice order.
# Captures used only by conditions may vary: only their participation matters.
# Example: /(?:(a)|\1)+/ => /(a)(?:(a)|a)*/
# with redundant noncapturing groups omitted: once set, \1 is always a.
class JsRegex::SecondPass::ExpandConstantCaptureLoops < JsRegex::SecondPass
  def call
    loop do
      @counts = reference_counts(tree)
      break if @counts.empty? || !expand(tree)

      renumber_captures
    end
  end

  private

  # In /x(?:(a)|\1)+y/, compile the loop together with its tail y, then
  # replace that suffix; return true after one such replacement.
  def expand(node)
    return false unless node.is_a?(Node)
    return false if repeated?(node)

    finish = sequence_end(node)
    if finish
      node.children.each.with_index do |child, index|
        next unless child.is_a?(Node) && child.quantifier && child.quantifier.max < 0 && child.quantifier.min <= 1

        following = Node.new(*node.children[(index + 1)...finish])
        replacement = catch(:unsupported_capture_loop) { compile(child, following) }
        next unless replacement

        node.update(children: [*node.children[0...index], replacement, *node.children[finish..-1]])
        return true
      end
    end
    node.children.any? { |child| expand(child) }
  end

  # For /(?:(a)|\1)+/, state 0 has no capture and must choose (a) first;
  # state 1 can then repeat either (a) or the known value a.
  def compile(node, following)
    groups = []
    walk(node) { |part| groups << part if part.type == :captured_group && @counts[part.reference] > 0 }
    return if groups.empty?

    references = groups.map(&:reference)
    internal = reference_counts(node)
    return unless groups.length > 1 || references.any? { |reference| internal[reference] > 0 } ||
      (node.quantifier.reluctant? && conditional_reference?(following, references))

    following_counts = reference_counts(following)
    return unless references.all? do |reference|
      internal[reference] + following_counts[reference] == @counts[reference]
    end

    @values = constant_capture_values(groups)
    # One bit per capture records whether it has participated in the loop.
    @capture_bits = references.each.with_index.to_h { |ref, idx| [ref, 1 << idx] }
    @all_captures = (1 << references.length) - 1
    @iteration = node.clone.update(quantifier: nil)
    @following = following
    @reluctant = node.quantifier.reluctant?
    @expanded_states = {}
    if node.optional?
      remaining_iterations(0)
    else
      alternate(iteration_paths(0).map { |part, state| Node.new(part, remaining_iterations(state)) })
    end
  rescue Regexp::Parser::Error, CharacterSet::ExpressionConverter::Error, Node::TypeError
    nil
  end

  # In /(?:(a)|ab)+?(?(1)c|a)/, the trailing condition needs capture 1's state
  # even after a later ab iteration skips it.
  def conditional_reference?(node, references)
    any_node?(node) do |part|
      if part.type == :conditional
        references.include?(part.reference)
      elsif part.type == :capture_conditional
        part.children.first.children.any? { |check| references.include?(check.reference) }
      end
    end
  end

  # Capture 1 containing /(ab)/ => {1 => /(?:ab)/}; /(a+)/ is allowed only
  # when conditions need its participation but no reference reads its value.
  def constant_capture_values(groups)
    groups.each_with_object({}) do |group, values|
      expression = Regexp::Parser.parse(group.children.join)
      unless constant_word(expression)
        throw :unsupported_capture_loop if capture_value_referenced?(group.reference)
        next
      end

      value = group.clone.update(quantifier: nil)
      walk(value) do |part|
        next unless part.type == :captured_group

        part.update(type: :plain, reference: nil, children: ['(?:', *part.children[1..-1]])
      end
      values[group.reference] = value
    end
  end

  # /(a+)(?(1)b|c)/ => false for capture 1; /(a+)\1/ => true.
  def capture_value_referenced?(reference)
    any_node? do |node|
      [:backref, :capture_check].include?(node.type) && node.reference == reference
    end
  end

  # Once capture 1 is set to a, the remaining /(?:(a)|\1)*/ iterations can
  # use /(?:(a)|a)*/ (redundant noncapturing groups omitted).
  def remaining_iterations(state)
    return @expanded_states[state].clone if @expanded_states.key?(state)

    if state == @all_captures
      body = substitute_known_captures(@iteration, state)
      tail = substitute_known_captures(@following, state)
      result = Node.new(repeat(body, @reluctant), tail)
    else
      result = repeat_without_new_captures(continuation_options(state))
    end
    @expanded_states[state] = result
  end

  # Each option either repeats the current state or continues to a new one.
  # Their order determines which choices backtracking tries first.
  # For /(?:(a)|b)*/ in state 0, (a) advances to state 1, b repeats state 0,
  # and stopping comes last; for *?, stopping comes first.
  def continuation_options(state)
    options = iteration_paths(state).map do |part, next_state|
      next_state == state ? [part, nil] : [nil, Node.new(part, remaining_iterations(next_state))]
    end
    ending = [nil, substitute_known_captures(@following, state)]
    @reluctant ? options.unshift(ending) : options.push(ending)
    options.reject! { |_, continuation| continuation && unmatchable?(continuation) }
    options
  end

  # Options [[/b/, nil], [nil, /c/]] => /(?:b)*c/: repeat b, then continue at c.
  def repeat_without_new_captures(options)
    loops = options.map(&:first).compact
    return alternate(options.map(&:last)) if loops.empty?

    first_loop = options.index { |part, _| part }
    last_loop = options.rindex { |part, _| part }
    before = options[0...first_loop].map(&:last)
    after = options[(last_loop + 1)..-1].map(&:last)
    throw :unsupported_capture_loop if options[first_loop..last_loop].any? { |_, continuation| continuation }

    # Regrouping these iterations must leave only one way to split the text.
    # Otherwise the regrouping could change backtracking order.
    unless before.empty? || after.empty? || unique_iteration_boundaries?(loops)
      throw :unsupported_capture_loop
    end
    loop_body = alternate(loops)
    branches = []
    branches << Node.new(repeat(loop_body.clone, true), alternate(before)) unless before.empty?
    branches << Node.new(repeat(loop_body, false), alternate(after)) unless after.empty?
    alternate(branches)
  end

  # [/a/, /b/] => true; [/a/, /ab/] => false because one word prefixes another.
  def unique_iteration_boundaries?(loops)
    words = loops.map { |part| constant_word(Regexp::Parser.parse(part.to_s)) }
    return false if words.any? { |word| !word || word.empty? }

    words.map!(&:downcase)
    words.combination(2).none? do |left, right|
      left.start_with?(right) || right.start_with?(left)
    end
  end

  # For /(?:(a)|\1)/ in state 0, keep only [(a), state 1]; \1 cannot yet match.
  def iteration_paths(state)
    expand_iteration(@iteration, state).reject { |part, _| unmatchable?(part) }.each do |part, _|
      throw :unsupported_capture_loop if Regexp::Parser.parse(part.to_s).match_length.min.zero?
    end
  end

  # With bit 1 assigned to capture 1, /(?:(a)|b)/ in state 0 yields
  # [(a), state 1] and [b, state 0].
  def expand_iteration(node, state)
    return [[node.clone, state]] if node.is_a?(String)

    updates = any_node?(node) do |part|
      part.type == :captured_group && @capture_bits.key?(part.reference)
    end
    return [[substitute_known_captures(node, state), state]] unless updates

    return optional_iteration_paths(node, state) if node.quantifier
    if node.type == :conditional || node.type == :capture_conditional
      selected = conditional_branch(node, state)
      throw :unsupported_capture_loop unless selected

      return expand_iteration(selected, state)
    end
    head = node.children.first
    throw :unsupported_capture_loop if head.is_a?(String) && head.start_with?('(') && !['(', '(?:'].include?(head)

    if alternation?(node)
      return node.children.flat_map do |branch|
        child = branch.clone.update(type: :plain)
        child.children.shift if child.children.first == '|'
        expand_iteration(child, state)
      end
    end
    sequence_paths(node, state)
  end

  # /(a)?/ in state 0 => [(a), state 1], ['', state 0]; ?? reverses the order.
  def optional_iteration_paths(node, state)
    throw :unsupported_capture_loop unless node.optional? && node.quantifier.max == 1

    present = expand_iteration(node.clone.update(quantifier: nil), state)
    absent = [[Node.new, state]]
    node.quantifier.reluctant? ? absent + present : present + absent
  end

  # /(a)\1/ starting in state 0 => /(a)(?:(?:a))/ in state 1:
  # the first child sets the capture before the second child reads it.
  def sequence_paths(node, state)
    results = [[[], state]]
    node.children.each do |child|
      results = results.flat_map do |parts, previous_state|
        following = expand_iteration(child, previous_state)
        if following.length > 1 && parts.any? { |part| can_backtrack?(part) }
          throw :unsupported_capture_loop
        end
        following.map { |part, next_state| [[*parts.map(&:clone), part], next_state] }
      end
    end
    results.map do |parts, next_state|
      next_state |= @capture_bits[node.reference] if node.type == :captured_group && @capture_bits.key?(node.reference)
      [node.copy_with_children(*parts), next_state]
    end
  end

  # If capture 1 holds a, \1 => /(?:(?:a))/; if it has not participated,
  # \1 => /(?:(?!))/ instead.
  def substitute_known_captures(node, state)
    return node.clone if node.is_a?(String)

    case node.type
    when :backref, :capture_backref, :multiplex_backref
      references = node.type == :backref ? [node.reference] : node.children.map(&:reference)
      if references.any? { |reference| @capture_bits.key?(reference) }
        throw :unsupported_capture_loop unless references.all? { |reference| @capture_bits.key?(reference) }

        reference = references.find { |number| state & @capture_bits[number] != 0 }
        value = reference ? @values[reference].clone : Node.new('(?!)')
        return node.copy_with_children('(?:', value, ')').update(type: :plain, reference: nil)
      end
    when :conditional, :capture_conditional
      selected = conditional_branch(node, state)
      if selected
        return node.copy_with_children('(?:', substitute_known_captures(selected, state), ')').update(type: :plain, reference: nil)
      end
    end
    node.copy_with_children(*node.children.map { |child| substitute_known_captures(child, state) })
  end

  # (?(1)b|c) selects b when bit 1 is set, and c when it is clear.
  def conditional_branch(node, state)
    references = node.type == :conditional ? [node.reference] : node.children.first.children.map(&:reference)
    return unless references.any? { |reference| @capture_bits.key?(reference) }

    throw :unsupported_capture_loop unless references.all? { |reference| @capture_bits.key?(reference) }
    present = references.any? { |reference| state & @capture_bits[reference] != 0 }
    branches = node.type == :conditional ? node.children[1...-1] : node.children[1..-1]
    (present ? branches[0] : branches[1]) || Node.new
  end

  # /(?:ab){2}/ => 'abab'; /a?/ => nil because its value can vary.
  def constant_word(expression)
    quantifier = expression.quantifier
    return unless !quantifier || quantifier.min == quantifier.max
    return '' if quantifier&.max&.zero?

    word = case expression.type
           when :literal then expression.text
           when :group, :expression
             children = expression.expressions.map { |child| constant_word(child) }
             children.join if children.all?
           when :escape
             characters = CharacterSet.of_expression(expression)
             characters.first.chr(Encoding::UTF_8) if characters.size == 1
           end
    word * (quantifier ? quantifier.min : 1) if word
  end

  # /a+/ => true; /a{2}/ => false.
  def can_backtrack?(node)
    return false if node.is_a?(String)
    return true if node.quantifier && node.quantifier.min != node.quantifier.max
    return true if [:backref, :capture_backref, :multiplex_backref, :conditional, :capture_conditional].include?(node.type)
    return true if node.children.any? { |child| branch?(child) }

    node.children.any? { |child| can_backtrack?(child) }
  end

  # (/a/, false) => /(?:a)*/; (/a/, true) => /(?:a)*?/.
  def repeat(node, reluctant)
    Node.new('(?:', node, ')').update(quantifier: Regexp::Expression::Quantifier.construct(text: "*#{'?' if reluctant}"))
  end
end
