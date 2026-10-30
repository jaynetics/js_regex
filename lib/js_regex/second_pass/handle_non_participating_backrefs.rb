# frozen_string_literal: true

# Make backreferences to skipped groups fail, as in Ruby, instead of matching
# an empty string as in JavaScript. Check capture values when they cannot be
# empty; otherwise, require the group to participate where the reference is required.
# Example: /\1(a)/ => /(?!)(a)/: the forward reference cannot succeed.
class JsRegex::SecondPass::HandleNonParticipatingBackrefs < JsRegex::SecondPass
  def call
    nodes, paths = reference_nodes_with_paths
    groups = {}
    nodes.each do |node|
      if node.type == :captured_group
        groups[node.reference] = node
      elsif node.type == :backref
        guard_backreference(node, groups[node.reference], paths)
      end
    end
  end

  private

  # /(a)|b\1/ => /(a)|b(?!)/: capture and reference are in different branches.
  def guard_backreference(node, capture, paths)
    path = paths[node]
    capture_path = capture && paths[capture]
    if !capture || path.include?(capture) || mutually_exclusive?(capture_path, path)
      node.update(type: :plain, reference: nil, children: ['(?!)'])
      return
    end

    skipped = capture_path.select { |ancestor| skippable_scope?(ancestor) } - path
    if skipped.any? { |ancestor| ancestor.negative_assertion? }
      node.update(type: :plain, reference: nil, children: ['(?!)'])
    elsif skipped.any?
      require_participation(node, capture, capture_path, path)
    end
  end

  # /(a)?\1/ => /(a)?(?:(?=[\s\S]*(?![\s\S])(?!\1))\1)/,
  # checking the capture at the reference without forcing the optional group.
  def require_participation(node, capture, capture_path, path)
    if capture.nonempty?
      reference = node.clone.update(quantifier: nil)
      node.update(type: :plain, reference: nil, children: ['(?:', nonempty_capture_check(reference.reference, true), reference, ')'])
    else
      require_nullable_capture(node, capture_path, path)
    end
  end

  # /(?:(a*)?\1)?/ => /(?:(a*)\1)?/: require the capture inside the shared
  # scope, while keeping that entire scope optional.
  def require_nullable_capture(backref, group_path, path)
    return if any_node?(path[-2]) do |node|
      node.type == :capture_check && node.reference == backref.reference
    end

    common_length = 0
    common_length += 1 while group_path[common_length] && group_path[common_length].equal?(path[common_length])
    common = group_path[common_length - 1]
    remaining_path = path[common_length..-1]
    return if remaining_path.any? { |ancestor| skippable_scope?(ancestor) }

    # Every match through this node uses the reference, so paths that skip its
    # capture cannot succeed. Keep the enclosing node's own optionality intact.
    quantifier = common.quantifier
    common.update(quantifier: nil)
    require_group_participation(common, backref.reference)
    common.update(quantifier: quantifier)
  end
end
