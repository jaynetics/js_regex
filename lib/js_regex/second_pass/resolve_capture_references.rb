# frozen_string_literal: true

# Expanded loops and subexpression calls can create several JavaScript groups
# for one Ruby capture. Resolve both its backreferences and participation tests
# against the same capture paths.
class JsRegex::SecondPass::ResolveCaptureReferences < JsRegex::SecondPass
  def call
    @group_paths = {}
    @optional_groups = potentially_absent_groups
    path = []
    walk(trace: true) do |node, event|
      if event == :exit
        @group_paths[node.reference] = path.dup if node.type == :captured_group
        path.pop
        next
      end
      path.push(node)
      case node.type
      when :capture_backref then resolve_backreference(node, path)
      when :capture_conditional then resolve_condition(node, path)
      end
    end
  end

  private

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

  def required_capture?(reference, path)
    !@optional_groups.include?(reference) || required_on_path?(@group_paths[reference], path)
  end

  def resolve_condition(node, path)
    references = node.children.first.children.map(&:reference)
    true_branch, false_branch = node.children[1..-1]
    if references.any? { |reference| required_on_path?(@group_paths[reference], path) }
      null_quantify(false_branch) if false_branch
      node.update(type: :plain, children: [true_branch, false_branch].compact)
    else
      present = alternate(references.map { |reference| nonempty_capture_check(reference, true) })
      absent = references.map { |reference| nonempty_capture_check(reference, false) }
      node.update(type: :plain, children: [alternate([
        Node.new(present, true_branch),
        Node.new(*absent, false_branch || Node.new),
      ])])
    end
  end
end
