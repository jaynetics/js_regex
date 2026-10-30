# frozen_string_literal: true

class JsRegex::SecondPass::HandleNonParticipatingBackrefs < JsRegex::SecondPass
  def call
    nodes, paths = reference_nodes_with_paths
    groups = {}
    nodes.each do |node|
      if node.type == :captured_group
        groups[node.reference] = node
      elsif node.type == :backref
        capture = groups[node.reference]
        path = paths[node]
        capture_path = capture && paths[capture]
        if !capture || path.include?(capture) || mutually_exclusive?(capture_path, path)
          node.update(type: :plain, reference: nil, children: ['(?!)'])
          next
        end

        skipped = capture_path.select { |ancestor| skippable_scope?(ancestor) } - path
        if skipped.any? { |ancestor| ['(?!', '(?<!'].include?(ancestor.children.first) }
          node.update(type: :plain, reference: nil, children: ['(?!)'])
        elsif skipped.any?
          require_participation(node, capture, capture_path, path)
        end
      end
    end
  end

  private

  def require_participation(node, capture, capture_path, path)
    if capture.nonempty?
      reference = node.clone.update(quantifier: nil)
      node.update(type: :plain, reference: nil, children: ['(?:', nonempty_capture_check(reference.reference, true), reference, ')'])
    else
      require_nullable_capture(node, capture_path, path)
    end
  end

  def require_nullable_capture(backref, group_path, path)
    checked = false
    path[-2].children.each do |sibling|
      walk(sibling) { |node| checked ||= node.type == :capture_check && node.reference == backref.reference }
    end
    return if checked

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
