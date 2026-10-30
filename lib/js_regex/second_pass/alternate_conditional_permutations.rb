# frozen_string_literal: true

# Builds (possibly nested) alternations to reflect the extrapolated branches of
# (possibly nested) conditional expressions. E.g. `(<)?a(?(1)>)` => `(?:<a>|a)`
# You will like this if you like brain teasers :D
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

  def conditions
    conditions = []
    walk do |node|
      conditions << node.reference if node.type.equal?(:conditional)
    end
    conditions.uniq
  end

  def captured_group_count
    count = 0
    walk { |node| count += 1 if node.type.equal?(:captured_group) }
    count
  end

  def condition_permutations(conditions)
    (0..(conditions.length)).inject([]) do |arr, n|
      arr + conditions.combination(n).to_a
    end
  end

  def build_permutation(node, conds, truthy_conds, caps_per_branch, i)
    truthy = truthy_conds.include?(node.reference)

    case node.type
    when :backref, :capture_check
      # We cannot use named groups or backrefs in the conditional expansion,
      # their repetition would cause a "Duplicate capture group name" error in JS.
      node.update(children: [
        node.children.first.sub(/k<.*>/, node.reference.to_s)
      ])
      # backref numbers need to be incremented for subsequent "branches"
      adapt_backref_to_permutation(node, caps_per_branch, i)
    when :captured_group
      # if the group is referenced by any condition, modulate its quantity
      if conds.include?(node.reference)
        adapt_referenced_group_to_permutation(node, truthy)
      end
      node.update(reference: node.reference + caps_per_branch * i)
    when :conditional
      adapt_conditional_to_permutation(node, truthy)
    end
  end

  def adapt_referenced_group_to_permutation(group_node, truthy)
    if truthy
      min_quantify(group_node)
    elsif group_node.optional?
      null_quantify(group_node)
    else
      # Keep mandatory captures mandatory. An enclosing optional group or
      # another alternative may still allow this capture not to participate.
      group_node.children.insert(1, Node.new('(?!)'))
    end
  end

  def adapt_conditional_to_permutation(conditional_node, truthy)
    branches = conditional_node.children[1...-1]
    if branches.count == 1
      truthy || null_quantify(branches.first)
    else
      null_quantify(truthy ? branches.last : branches.first)
    end
    conditional_node.update(type: :plain)
  end

  def adapt_backref_to_permutation(backref_node, caps_per_branch, i)
    new_num = backref_node.reference + caps_per_branch * i
    backref_node.update(children: ["\\#{new_num}"], reference: new_num)
  end
end
