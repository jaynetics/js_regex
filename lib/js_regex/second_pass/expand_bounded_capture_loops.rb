# frozen_string_literal: true

# Give each iteration its own captures. A later iteration can then skip a
# capture without clearing the value stored by an earlier one in JavaScript.
class JsRegex::SecondPass::ExpandBoundedCaptureLoops < JsRegex::SecondPass
  def call
    @references = reference_counts(tree).keys
    expand(tree)
    renumber_captures if @expanded
  end

  private

  def expand(node)
    return unless node.is_a?(Node)

    node.children.each { |child| expand(child) }
    quantity = node.quantifier
    return unless quantity && quantity.max > 1

    iteration = node.clone.update(quantifier: nil)
    nullable = may_match_empty?(iteration)
    references = potentially_absent_groups(iteration)
    walk(iteration) { |part| references << part.reference if nullable && part.type == :captured_group }
    return if (references & @references).empty?

    tail = unroll(iteration, quantity, nullable)
    node.update(type: :plain, reference: nil, quantifier: nil, children: [tail])
    @expanded = true
  end

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

  def may_match_empty?(node)
    Regexp::Parser.parse(node.to_s).match_length.min.zero?
  rescue Regexp::Parser::Error, Node::TypeError
    true
  end
end
