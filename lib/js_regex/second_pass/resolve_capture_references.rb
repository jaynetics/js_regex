# frozen_string_literal: true

# Resolve references to a Ruby capture represented by several JavaScript groups
# after loop expansion or subexpression calls. Backreferences use the latest
# participating copy; conditionals check whether any copy participated.
# Duplicate names try participating values newest first and commit to the first
# match, even if the rest of the pattern later fails.
# Optional nonempty captures can also be tested here, keeping their conditions
# in place so that greedy and lazy choices retain their original priority.
# Example: /(?<n>a)(?<n>b)\k<n>/ => /(a)(b)(?:\2|(?!\2)\1)/.
class JsRegex::SecondPass::ResolveCaptureReferences < JsRegex::SecondPass
  def call
    @group_paths = {}
    @groups = {}
    @optional_groups = potentially_absent_groups
    path = []
    walk(trace: true) do |node, event|
      if event == :exit
        if node.type == :captured_group
          @group_paths[node.reference] = path.dup
          @groups[node.reference] = node
        end
        path.pop
        next
      end
      path.push(node)
      case node.type
      when :conditional
        if optional_consuming_capture?(node.reference, path)
          make_condition_dynamic(node)
          resolve_condition(node, path)
        end
      when :multiplex_backref then resolve_multiplexed_backreference(node, path)
      when :capture_backref then resolve_backreference(node, path)
      when :capture_conditional then resolve_condition(node, path)
      end
    end
  end

  private

  # Three mandatory candidates [3, 2, 1] => /(?:\3|(?!\3)(?:\2|(?!\2)\1))/;
  # a failed continuation cannot make a matching candidate give way to an older one.
  def resolve_multiplexed_backreference(node, path)
    references = node.children.select { |reference| @group_paths.key?(reference.reference) }
    alternatives = references.map { |reference| guard_named_reference(reference, path) }
    choice = alternatives.reverse_each.reduce do |fallback, preferred|
      # Nest fallbacks so each candidate needs only one exclusion check.
      alternate([preferred, Node.new('(?!', preferred.clone, ')', fallback)])
    end
    node.update(type: :plain, children: [choice || Node.new('(?!)')])
  end

  # For an optional nullable capture, \1 becomes a condition equivalent to
  # (?(1)\1|(?!)); a later pass expands that condition.
  def guard_named_reference(reference, path)
    return reference if required_capture?(reference.reference, path)

    if @groups.fetch(reference.reference).nonempty?
      Node.new(nonempty_capture_check(reference.reference, true), reference)
    else
      Node.new('(?:', Node.new('(?:', reference, ')'), Node.new('(?:(?!))'), ')',
               reference: reference.reference, type: :conditional)
    end
  end

  # Capture 1 in /(a)?(?(1)b|c)/ => true; in /(a*)?(?(1)b|c)/ => false,
  # since an empty capture cannot be distinguished from absence by its value.
  def optional_consuming_capture?(reference, path)
    group = @groups[reference]
    return false unless group && group.nonempty? && !required_capture?(reference, path)

    # Captures inside lookarounds can belong to atomic-group emulation. Leave
    # those under the existing conditional permutation rules.
    @group_paths[reference].none? do |ancestor|
      ancestor.positive_assertion? || ancestor.atomic?
    end
  end

  # history[2,1] => \2 when capture 2 is required; an empty history => /(?!)/.
  def resolve_backreference(node, path)
    references = node.children.select { |reference| @group_paths.key?(reference.reference) }
    if references.empty?
      node.update(type: :plain, children: ['(?!)'])
    elsif required_capture?(references.first.reference, path)
      node.update(type: :plain, children: [references.first])
    else
      branches = []
      absent_checks = []
      references.each do |reference|
        branches << Node.new(*absent_checks, nonempty_capture_check(reference.reference, true), reference)
        absent_checks += [nonempty_capture_check(reference.reference, false)]
        break unless @optional_groups.include?(reference.reference)
      end
      node.update(type: :plain, children: [alternate(branches)])
    end
  end

  # Capture 1 at \1 in /(?:(a)\1)?/ => true; in /(a)?\1/ => false.
  def required_capture?(reference, path)
    !@optional_groups.include?(reference) || required_on_path?(@group_paths[reference], path)
  end

  # After a required capture 1, /(?(1)b|c)/ => /(?:(?:b))/.
  def resolve_condition(node, path)
    references = node.children.first.children.map(&:reference)
    if references.any? { |reference| required_on_path?(@group_paths[reference], path) }
      select_conditional_branch(node, true)
    else
      true_branch, false_branch = node.children[1..-1]
      present = alternate(references.map { |reference| nonempty_capture_check(reference, true) })
      absent = references.map { |reference| nonempty_capture_check(reference, false) }
      node.update(type: :plain, children: [alternate([
        Node.new(present, true_branch),
        Node.new(*absent, false_branch || Node.new),
      ])])
    end
  end
end
