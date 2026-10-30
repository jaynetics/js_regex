# frozen_string_literal: true

class JsRegex::SecondPass::HandleNonParticipatingBackrefs < JsRegex::SecondPass
  def call
    completed_group_numbers = {}
    group_branches = {}
    branch_stack = []
    branch_owners = {}

    walk do |parent|
      parent.children.each do |child|
        branch_owners[child] = parent if child.is_a?(Node) && child.type == :branch
      end
    end

    walk(trace: true) do |node, event|
      case [node.type, event]
      when [:branch, :enter]
        branch_stack.push(node)
      when [:branch, :exit]
        branch_stack.pop
      when [:captured_group, :exit]
        unless node.optional? # ignore optional groups
          group_branches[node.reference] = branch_stack.dup
        end
        completed_group_numbers[node.reference] = true
      when [:backref, :exit]
        # make bad backrefs non-matchable
        references_other_branch = Array(group_branches[node.reference]).any? do |ref_branch|
          branch_stack.any? do |current_branch|
            branch_owners[ref_branch].equal?(branch_owners[current_branch]) &&
              !ref_branch.equal?(current_branch)
          end
        end
        forward_reference = !completed_group_numbers[node.reference]
        if references_other_branch || forward_reference
          node.update(type: :plain, children: ['(?!)'])
        end
      end
    end
  end
end
