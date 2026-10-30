# frozen_string_literal: true

class JsRegex::SecondPass::GuardMultiplexedBackrefs < JsRegex::SecondPass
  def call
    walk { |node| guard(node) if node.type == :multiplex_backref }
  end

  def guard(node)
    alternatives = node.children.map { |backref| substitute(backref) }
    children = ['(?:']
    alternatives.each.with_index { |branch, i| children.concat(i.zero? ? [branch] : ['|', branch]) }
    node.update(type: :plain, children: children + [')'])
  end

  def substitute(backref)
    return backref unless optional_groups.include?(backref.reference)

    if backref.nonempty?
      Node.new(capture_check(backref.reference, true), backref)
    else
      Node.new('(?:', Node.new('(?:', backref, ')'), Node.new('(?:(?!))'), ')',
                reference: backref.reference, type: :conditional)
    end
  end

  def optional_groups
    @optional_groups ||= potentially_absent_groups
  end
end
