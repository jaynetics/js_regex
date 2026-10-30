# frozen_string_literal: true

# Replace capture conditionals with alternatives that JavaScript can match.
# Each alternative copies the pattern for one combination of participating
# groups, requires or excludes those groups, and selects the matching branches.
# Example: /(a)?(?(1)b|c)/ => /(){0}c|(a)b/
# with redundant noncapturing groups omitted.
class JsRegex::SecondPass::AlternateConditionalPermutations < JsRegex::SecondPass
  def call
    permutations = conditional_tree_permutations
    return if permutations.empty?

    alternatives = permutations.map.with_index do |variant, i|
      Node.new((i.zero? ? '(?:' : '|(?:'), variant, ')', type: :branch)
    end
    tree.update(children: alternatives)
  end

  private

  # For /(a)?(?(1)b|c)/, produce an absent variant and a present variant:
  # /(){0}c/ and /(a)b/ (redundant noncapturing groups omitted).
  def conditional_tree_permutations
    conds = conditions
    return [] if conds.empty?

    caps_per_branch = captured_group_count

    condition_permutations(conds).map.with_index do |truthy_conds, i|
      tree_permutation = tree.clone
      # find referenced groups and conditionals and make one-sided
      walk(tree_permutation) do |node|
        build_permutation(node, conds, truthy_conds, caps_per_branch, i)
      end
      truthy_conds.each do |reference|
        require_group_participation(tree_permutation, reference + caps_per_branch * i)
      end
      tree_permutation
    end
  end

  # /(a)?(?(1)b|c)(?(1)d|e)/ => [1], counting the repeated condition once.
  def conditions
    conditions = []
    walk do |node|
      conditions << node.reference if node.type.equal?(:conditional)
    end
    conditions.uniq
  end

  # /(a)(?:b(c))/ => 2.
  def captured_group_count
    count = 0
    walk { |node| count += 1 if node.type.equal?(:captured_group) }
    count
  end

  # [1, 2] => [[], [1], [2], [1, 2]], the captures present in each variant.
  def condition_permutations(conditions)
    (0..(conditions.length)).inject([]) do |arr, n|
      arr + conditions.combination(n).to_a
    end
  end

  # With one capture per variant, \1 in the second variant => \2.
  def build_permutation(node, conds, truthy_conds, caps_per_branch, i)
    truthy = truthy_conds.include?(node.reference)

    case node.type
    when :backref, :capture_check
      node.renumber(node.reference + caps_per_branch * i)
    when :captured_group
      # if the group is referenced by any condition, modulate its quantity
      if conds.include?(node.reference)
        adapt_referenced_group_to_permutation(node, truthy)
      end
      node.renumber(node.reference + caps_per_branch * i)
    when :conditional
      select_conditional_branch(node, truthy)
    end
  end

  # /(a)?/ => /(a)/ when present, or /(){0}/ when absent.
  def adapt_referenced_group_to_permutation(group_node, truthy)
    if truthy
      min_quantify(group_node)
    elsif group_node.optional?
      discard_contents(group_node)
    else
      # Keep mandatory captures mandatory. An enclosing optional group or
      # another alternative may still allow this capture not to participate.
      group_node.children.insert(1, Node.new('(?!)'))
    end
  end
end
