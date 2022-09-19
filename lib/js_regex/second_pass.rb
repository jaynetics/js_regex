class JsRegex
  #
  # After conversion of a full Regexp::Expression tree, this
  # checks for Node instances that need further processing.
  #
  module SecondPass
    class << self
      def call(tree)
        substitute_root_level_keep_mark(tree)
        alternate_conditional_permutations(tree)
        tree
      end

      private

      def substitute_root_level_keep_mark(tree)
        keep_mark_index = nil
        tree.children.each.with_index do |child, i|
          break keep_mark_index = i if child.type == :keep_mark
        end
        return unless keep_mark_index

        pre = tree.children[0...keep_mark_index]
        post = tree.children[(keep_mark_index + 1)..-1]
        lookbehind = Node.new('(?<=', *pre, ')')
        tree.update(children: [lookbehind, *post])
      end

      def alternate_conditional_permutations(tree)
        permutations = conditional_tree_permutations(tree)
        return if permutations.empty?

        alternatives = permutations.map.with_index do |variant, i|
          Node.new((i.zero? ? '(?:' : '|(?:'), variant, ')')
        end
        tree.update(children: alternatives)
      end

      def conditional_tree_permutations(tree)
        conds = conditions(tree)
        return [] if conds.empty?

        caps_per_branch = captured_group_count(tree)

        condition_permutations(conds).map.with_index do |truthy_conds, i|
          tree_permutation = tree.clone
          # find referenced groups and conditionals and make one-sided
          crawl(tree_permutation) do |node|
            build_permutation(node, conds, truthy_conds, caps_per_branch, i)
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
          arr + conditions.combination(n).to_a
        end
      end

      def build_permutation(node, conds, truthy_conds, caps_per_branch, i)
        truthy = truthy_conds.include?(node.reference)

        case node.type
        when :backref
          # We cannot use named groups or backrefs in the conditional expansion,
          # their repetition would cause a "Duplicate capture group name" error in JS.
          node.update(children: [
            node.children.first.sub(/k<.*>/, node.reference.to_s)
          ])
          # backref numbers need to be incremented for subsequent "branches"
          adapt_backref_to_permutation(node, caps_per_branch, i)
        when :captured_group
          # Remove name, c.f. :backref handling.
          node.update(children: [
            node.children.first.sub(/\?<.*>/, ''),
            *node.children[1..-1]
          ])
          # if the group is referenced by any condition, modulate its quantity
          if conds.include?(node.reference)
            adapt_referenced_group_to_permutation(node, truthy)
          end
        when :conditional
          adapt_conditional_to_permutation(node, truthy)
        end
      end

      def adapt_referenced_group_to_permutation(group_node, truthy)
        truthy ? min_quantify(group_node) : null_quantify(group_node)
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
        backref_node.update(children: ["\\#{new_num}"])
      end

      def min_quantify(node)
        return if guarantees_at_least_one_match?(qtf = node.quantifier)

        if qtf.max.equal?(1) # any zero_or_one quantifier (?, ??, ?+)
          node.update(quantifier: nil)
        else
          min_quantifier = qtf.dup
          min_quantifier.text = "{1,#{qtf.max}}#{'?' if qtf.reluctant?}"
          node.update(quantifier: min_quantifier)
        end
      end

      def guarantees_at_least_one_match?(quantifier)
        quantifier.nil? || quantifier.min > 0
      end

      def null_quantify(node)
        null_quantifier = Regexp::Expression::Quantifier.construct(text: '{0}')
        node.update(quantifier: null_quantifier)
      end
    end
  end
end
