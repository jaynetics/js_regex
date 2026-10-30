# frozen_string_literal: true

# Expand finite repetitions so each iteration has its own capture groups.
# This preserves earlier captures when later iterations skip those groups,
# and preserves Ruby's stopping rule for repeated empty iterations.
# Example: /(?:(a)|b){2}\1/ => /(?:(a)|b)(?:(a)|b)history[2,1]/.
# The history is resolved later to the latest participating copy of (a).
class JsRegex::SecondPass::ExpandBoundedCaptureLoops < JsRegex::SecondPass
  def call
    @references = reference_counts(tree).keys
    return if @references.empty?

    expand(tree)
    renumber_captures if @expanded
  end

  private

  # /(?:(a)|b){2}\1/ unrolls its loop; /(a){2}\1/ stays as-is because
  # every iteration necessarily updates the referenced capture.
  def expand(node)
    return unless node.is_a?(Node)

    node.children.each { |child| expand(child) }
    quantity = node.quantifier
    return unless quantity&.max&.>(1)

    return unless any_node?(node) { |part| part.type == :captured_group && @references.include?(part.reference) }

    iteration = node.clone.update(quantifier: nil)
    nullable = may_match_empty?(iteration)
    references = potentially_absent_groups(iteration)
    if nullable
      walk(iteration) { |part| references << part.reference if part.type == :captured_group }
    end
    return if (references & @references).empty?

    tail = unroll(iteration, quantity, nullable)
    node.update(type: :plain, reference: nil, quantifier: nil, children: [tail])
    @expanded = true
  end

  # Body /(?:(a)|b)/ with {2} => /(?:(a)|b)(?:(a)|b)/, before renumbering.
  def unroll(iteration, quantity, nullable)
    positions = Array.new(quantity.max) do |index|
      temporary_capture('[\\s\\S]*') if nullable && index + 2 < quantity.max
    end
    tail = Node.new
    quantity.max.downto(1) do |index|
      current = Node.new(iteration.clone, tail)
      probe = positions[index - 1]
      current.children.unshift(Node.new('(?=', probe, ')')) if probe
      previous_position = index > 2 ? positions[index - 3] : nil
      tail = iteration_choice(current, index, quantity, previous_position)
    end
    tail
  end

  # For the optional second iteration of {1,2}, /a/ => /(?:a|)/;
  # for {1,2}?, /a/ => /(?:|a)/.
  def iteration_choice(current, index, quantity, previous_position)
    # Ruby permits one empty iteration before its loop check sees the same
    # position again. Keep that last empty capture when the loop stops.
    if previous_position
      current = Node.new(require_progress(previous_position.reference), current)
    end
    if index > quantity.min
      branches = [current, Node.new]
      branches.reverse! if quantity.reluctant?
      alternate(branches)
    elsif previous_position
      stopped = Node.new('(?=', capture_value(previous_position.reference), ')')
      alternate([current, stopped])
    else
      current
    end
  end

  # /a?/ => true; /a/ => false.
  def may_match_empty?(node)
    Regexp::Parser.parse(node.to_s).match_length.min.zero?
  rescue Regexp::Parser::Error, Node::TypeError
    true
  end
end
