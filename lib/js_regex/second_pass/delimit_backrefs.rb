# frozen_string_literal: true

class JsRegex::SecondPass::DelimitBackrefs < JsRegex::SecondPass
  def call
    delimit_backrefs(tree, '')
  end

  def delimit_backrefs(node, following)
    following = node.quantifier.to_s[0] || following
    if node.type == :backref && /\A[0-9]/.match(following) &&
        /\\[0-9]+\z/.match(node.children.last.to_s)
      node << '(?:)'
    end

    node.children.reverse_each do |child|
      delimit_backrefs(child, following) if child.is_a?(Node)
      first = child.to_s[0]
      following = first if first
    end
  end
end
