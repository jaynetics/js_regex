# frozen_string_literal: true

# Replace supported \K marks with lookbehind for the preceding part of the branch.
# That text must still match, but is excluded from the returned match.
# Example: /a\Kb/ => /(?<=a)b/.
class JsRegex::SecondPass::SubstituteRootLevelKeepMark < JsRegex::SecondPass
  def call
    substitute_in(tree)
  end

  # /a\Kb\Kc/ => /(?<=ab)c/: only the last mark sets the match start.
  def substitute_in(node)
    node.children.each do |child|
      substitute_in(child) if child.is_a?(Node)
    end

    keep_mark_index = node.children.rindex { |child| child.is_a?(Node) && child.type == :keep_mark }
    return unless keep_mark_index

    pre = node.children[0...keep_mark_index].reject { |child| child.is_a?(Node) && child.type == :keep_mark }
    separator = pre.first == '|' ? [pre.shift] : []
    post = node.children[(keep_mark_index + 1)..-1]
    lookbehind = Node.new('(?<=', *pre, ')')
    node.update(children: [*separator, lookbehind, *post])
  end
end
