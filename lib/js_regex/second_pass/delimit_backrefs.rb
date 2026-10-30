# frozen_string_literal: true

# Separate numeric backreferences from following literal digits with (?:).
# Otherwise JavaScript could read a reference followed by a digit, such as
# \1 followed by 0, as a different reference or an octal escape.
# Example: /(a)\1 0/x => /(a)\1(?:)0/.
class JsRegex::SecondPass::DelimitBackrefs < JsRegex::SecondPass
  def call
    delimit_backrefs(tree, '')
  end

  # A /\1/ node with following = '0' becomes /\1(?:)/ and returns '\'
  # as its first character; following = 'a' leaves it unchanged.
  def delimit_backrefs(node, following)
    quantifier_start = node.quantifier && node.quantifier.to_s[0]
    following = quantifier_start || following
    if node.type == :backref && /\A[0-9]/.match(following) &&
        /\\[0-9]+\z/.match(node.children.last.to_s)
      node << '(?:)'
    end

    first = quantifier_start
    node.children.reverse_each do |child|
      child_start = child.is_a?(Node) ? delimit_backrefs(child, following) : child[0]
      first = following = child_start if child_start
    end
    # Return the first character while visiting the children, rather than
    # rendering each subtree again just to inspect its first character.
    first unless node.dropped?
  end
end
