# frozen_string_literal: true

class JsRegex::SecondPass::SubstituteRootLevelKeepMark < JsRegex::SecondPass
  def call
    substitute_in(tree)
  end

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
