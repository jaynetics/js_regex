# frozen_string_literal: true

class JsRegex
  #
  # After conversion of a full Regexp::Expression tree, this
  # checks for Node instances that need further processing.
  #
  module SecondPass
    class << self
      def call(tree)
        alternate_conditional_permutations(tree)
        tree
      end

      private

      def alternate_conditional_permutations(tree)
        permutations = conditional_tree_permutations(tree)
        return if permutations.empty?

        alternatives = permutations.map.with_index do |variant, i|
          Node.new((i.zero? ? '(?:' : '|(?:'), variant, ')')
        end
        tree.update(children: alternatives)
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

      def crawl(node, &block)
        return if node.instance_of?(String)
        yield(node)
        node.children.each { |child| crawl(child, &block) }
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
        crawl(tree) { |node| count += 1 if node.type.equal?(:captured_group) }
        count
      end

      def condition_permutations(conditions)
        (0..(conditions.length)).inject([]) do |arr, n|
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
end
