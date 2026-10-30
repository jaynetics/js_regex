# frozen_string_literal: true

class JsRegex::SecondPass::GuardMultiplexedBackrefs < JsRegex::SecondPass
  def call
    @group_paths = {}
    @groups = {}
    @paths = {}
    references = []
    path = []
    walk(trace: true) do |node, event|
      if event == :enter
        path.push(node)
        if node.type == :multiplex_backref
          @paths[node] = path.dup
          references << node
        end
      else
        if node.type == :captured_group
          @group_paths[node.reference] = path.dup
          @groups[node.reference] = node
        end
        path.pop
      end
    end
    references.each { |node| guard(node) }
  end

  private

  def guard(node)
    alternatives = node.children.map { |backref| substitute(backref, @paths[node]) }
    children = ['(?:']
    alternatives.each.with_index { |branch, i| children.concat(i.zero? ? [branch] : ['|', branch]) }
    node.update(type: :plain, children: children + [')'])
  end

  def substitute(backref, path)
    return backref if !optional_groups.include?(backref.reference) ||
      required_on_path?(@group_paths[backref.reference], path)

    if @groups.fetch(backref.reference).nonempty?
      Node.new(nonempty_capture_check(backref.reference, true), backref)
    else
      Node.new('(?:', Node.new('(?:', backref, ')'), Node.new('(?:(?!))'), ')',
                reference: backref.reference, type: :conditional)
    end
  end

  def optional_groups
    @optional_groups ||= potentially_absent_groups
  end
end
