# frozen_string_literal: true

class JsRegex
  #
  # After conversion of a full Regexp::Expression tree, this class
  # checks for Node instances that need further processing.
  #
  # E.g. subexpression calls (such as \g<1>) can be look-ahead,
  # so the full Regexp must have been processed first, and only then can
  # they be substituted with the conversion result of their targeted group.
  #
  module SecondPass
    module_function

    def call(tree)
      substitute_subexp_calls(tree)
      alternate_conditional_permutations(tree)
      tree
    end

    def substitute_subexp_calls(tree)
      crawl(tree) do |node|
        if node.type == :subexp_call
          called_group = find_group_by_reference(node.reference, in_node: tree)
          node.update(children: called_group.children, type: :captured_group)
        end
      end
    end

    def crawl(node, &block)
      return if node.instance_of?(String)
      yield(node)
      node.children.each { |child| crawl(child, &block) }
    end

    def alternate_conditional_permutations(tree)
      permutations = conditional_tree_permutations(tree)
      return tree if permutations.empty?

      alternatives = permutations.map.with_index do |variant, i|
        Node.new((i.zero? ? '(?:' : '|(?:'), variant, ')')
      end
      tree.update(children: alternatives)
    end

    def find_group_by_reference(ref, in_node: nil)
      crawl(in_node) do |node|
        return node if node.type == :captured_group && node.reference == ref
      end
      Node.new('()')
    end

    def conditional_tree_permutations(tree)
      all_conditions = conditions(tree)
      return [] if all_conditions.empty?

      captured_groups_per_branch = captured_group_count(tree)

      condition_permutations(all_conditions).map.with_index do |truthy_conds, i|
        tree_permutation = tree.clone
        # find referenced groups and conditionals and make one-sided
        crawl(tree_permutation) do |node|
          truthy = truthy_conds.include?(node.reference)

          if node.type.equal?(:captured_group) &&
             all_conditions.include?(node.reference)
            truthy ? min_quantify(node) : null_quantify(node)
          elsif node.type.equal?(:conditional)
            branches = node.children[1...-1]
            if branches.count == 1
              truthy || null_quantify(branches.first)
            else
              null_quantify(truthy ? branches.last : branches.first)
            end
            node.update(type: :plain)
          elsif node.type.equal?(:backref_num)
            new_num = node.children[0].to_i + captured_groups_per_branch * i
            node.update(children: [new_num.to_s])
          end
        end
      end
    end

    def conditions(tree)
      conditions = []
      crawl(tree) do |node|
        conditions << node.reference if node.type.equal?(:conditional)
      end
      conditions
    end

    def captured_group_count(tree)
      count = 0
      crawl(tree) { |node| count += 1 if node.type.equal?(:captured_group)}
      count
    end

    def condition_permutations(conditions)
      return [] if conditions.empty?

      condition_permutations = (0..(conditions.length)).inject([]) do |arr, n|
        arr += conditions.combination(n).to_a
      end
    end

    def min_quantify(node)
      return if (qtf = node.quantifier).nil? || qtf.min > 0

      if qtf.max.equal?(1) # any zero_or_one quantifier (?, ??, ?+)
        node.update(quantifier: nil)
      else
        node.update(quantifier: "{1,#{qtf.max}}#{'?' if qtf.reluctant?}")
      end
    end

    def null_quantify(node)
      node.update(quantifier: '{0}')
    end
  end
end
