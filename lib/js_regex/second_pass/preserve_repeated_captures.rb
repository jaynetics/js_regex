# frozen_string_literal: true

# Ruby retains captures skipped by later iterations; JavaScript clears them.
# Keep retained captures outside iterations that can skip them, either by
# isolating the last update or grouping each update with its following skips.
class JsRegex::SecondPass::PreserveRepeatedCaptures < JsRegex::SecondPass
  def call
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
    rewrite_repetitions(tree)
    renumber_captures if @rewritten
  end

  private

  def skipped_captures(node = tree, optional = false)
    return [] if node.is_a?(String) || unmatchable?(node)

    optional ||= node.optional? || node.type == :conditional || ['(?!', '(?<!'].include?(node.children.first)
    children = node.children
    if children.any? && children.all? { |child| branch?(child) }
      children = children.reject { |child| unmatchable?(child) }
      optional ||= children.length > 1
    end
    groups = optional && node.type == :captured_group ? [node.reference] : []
    children.each { |child| groups.concat(skipped_captures(child, optional)) }
    groups
  end

  def rewrite_repetitions(node)
    return unless node.is_a?(Node)

    node.children.each { |child| rewrite_repetitions(child) }
    quantifier = node.quantifier
    return unless quantifier && quantifier.max < 0

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

  def prefix_counts(quantifier)
    minimum = [quantifier.min - 1, 0].max
    counts = (0...minimum).map { |count| [count, count] } + [[minimum, -1]]
    quantifier.reluctant? ? counts : counts.reverse
  end

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

    captured_first = first_characters(captured_expression).case_insensitive
    skipped_first = first_characters(skipped_expression).case_insensitive
    disjoint = (captured_first & skipped_first).empty?
    capture = Regexp::Parser.parse(target.children.join)
    nullable = target.nullable? && disjoint && !quantifier.reluctant?
    unary = target.nonempty? && CharacterSet.of_expression(capture).size == 1 && !quantifier.reluctant?
    if !internal_reference && (capture.match_length.fixed? || nullable || unary) &&
        (disjoint || (single_capture && mandatory && !quantifier.reluctant?))
      [:last, nil]
    elsif (disjoint || (single_capture && mandatory && quantifier.reluctant?)) &&
        quantifier.min <= 1 && skipped_expression.match_length.min > 0
      [:retained, nil]
    end
  rescue Regexp::Parser::Error, CharacterSet::ExpressionConverter::Error, Node::TypeError
    nil
  end

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

  def replace_loop(node, present_branches, absent, reluctant)
    branches = reluctant ? [absent, *present_branches] : [*present_branches, absent]
    node.update(type: :plain, reference: nil, quantifier: nil, children: [alternate(branches)])
  end

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

  def first_characters(expression)
    return CharacterSet.new if expression.quantifier && expression.quantifier.max.zero?

    case expression.type
    when :literal
      CharacterSet.of_string(expression.text[0].to_s)
    when :assertion, :anchor
      CharacterSet.new
    when :group, :expression
      result = CharacterSet.new
      expression.expressions.each do |child|
        result |= first_characters(child)
        break unless child.match_length.min.zero?
      end
      result
    when :meta
      if expression.token == :dot
        CharacterSet.unicode
      else
        expression.expressions.map { |child| first_characters(child) }.reduce(CharacterSet.new, :|)
      end
    else
      CharacterSet.of_expression(expression)
    end
  end

  def quantity(minimum, maximum, reluctant)
    maximum = '' if maximum < 0
    Regexp::Expression::Quantifier.construct(text: "{#{minimum},#{maximum}}#{'?' if reluctant}")
  end

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
