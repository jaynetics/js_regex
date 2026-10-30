# frozen_string_literal: true

class JsRegex
  # Run ordered rewrites on the converted node tree to preserve Ruby matching
  # semantics in JavaScript. Share traversal, capture analysis, and node-building
  # helpers with the individual steps.
  # Example: /\1(a)/ => /(?!)(a)/, since Ruby rejects the forward reference.
  class SecondPass
    Node = JsRegex::Node

    Dir[File.join(__dir__, 'second_pass', '*.rb')].sort.each do |file|
      require file
    end

    # `tree` is a JsRegex::Node. SecondPass and its subclasses mutate it.
    def self.call(tree)
      new(tree).call
      tree
    end

    def initialize(tree)
      self.tree = tree
    end

    def call
      # the whole second pass is only needed if the regexp uses specific features.
      return unless tree.walk.any? { |node| node.internal_reference? || node.type == :keep_mark }

      STEPS.each { |step| step.call(tree) }
    end

    STEPS = [
      SubstituteRootLevelKeepMark,
      # Expand bounded loops first so later steps can inspect each iteration.
      ExpandBoundedCaptureLoops,
      ExpandNullableCaptures,
      ExpandConstantCaptureLoops,
      PreserveRepeatedCaptures,
      # Resolve capture histories after all rewrites that can duplicate groups.
      ResolveCaptureReferences,
      AlternateConditionalPermutations,
      HandleNonParticipatingBackrefs,
      # Conditional expansion can renumber references, so delimit them last.
      DelimitBackrefs,
    ].freeze

    private

    attr_accessor :tree

    #
    # Shared helper methods used in multiple subclasses / steps
    #

    # Children ['(?:', a, ')'] => 2, the insertion point before the closing ')'.
    def sequence_end(node)
      return if node.alternation? || node.conditional?

      head = node.children.first
      if ['(', '(?:', '(?=', '(?!', '(?<=', '(?<!'].include?(head) && node.children.last == ')'
        node.children.length - 1
      elsif !(head.instance_of?(String) && head.start_with?('('))
        node.children.length
      end
    end

    # /(a)\1\1/ => {1 => 2}; the capture itself is not counted.
    def reference_counts(node)
      counts = Hash.new(0)
      node.walk { |n| counts[n.reference] += 1 if n.reference && n.type != :captured_group }
      counts
    end

    # Capture 1 at \1 in /(a)\1/ => true; in /(a)?\1/ => false.
    def required_on_path?(group_path, path)
      group_path&.all? do |ancestor|
        !skippable_scope?(ancestor) || path.include?(ancestor)
      end
    end

    # /(a)?/ => true; /(a)/ => false; a branch of /a|b/ => true.
    def skippable_scope?(node)
      node.optional? || node.branch? || node.negative_assertion?
    end

    # Force a node to occur at least once (unless it is quantified with {0,0}).
    # /(a)?/ => /(a)/; /(a)*?/ => /(a){1,}?/.
    def min_quantify(node)
      return unless node.optional?

      if node.zero_quantified?
        node.update(children: ['(?!)', *node.children], quantifier: nil)
      elsif node.max_one?
        node.update(quantifier: nil)
      else
        node.update(quantifier: node.quantifier.with_minimum_one)
      end
    end

    # Discard a node's contents, retaining only disabled capture slots.
    # /(a(b))+/ => /(()){0}/; /(?:abc)/ => an empty sequence.
    # Plain () would participate; quantifying with {0} keeps it unmatched.
    def discard_contents(node)
      captures = []
      node.walk(skip_self: true) { |el| captures << empty_capture(el) if el.type == :captured_group }
      if node.type == :captured_group
        node.update(children: ['(', *captures, ')'])
      elsif captures.empty?
        return node.update(type: :plain, reference: nil, children: [], quantifier: nil)
      else
        node.update(type: :plain, reference: nil, children: ['(?:', *captures, ')'])
      end
      node.quantify(0, 0)
    end

    # A copy of /(a*)+/ => /()/, with the same capture ID and an empty value.
    def empty_capture(capture)
      Node.new('(', ')', reference: capture.reference, type: :captured_group, nullable: true)
    end

    # With capture 1 present: /(?(1)b|(c))/ => /(?:(?:b)(?:()){0})/.
    # Keep discarded captures in source order so later references keep their numbers.
    def select_conditional_branch(node, truthy)
      branches = node.conditional_branches
      branches.each.with_index { |branch, i| discard_contents(branch) unless i == (truthy ? 0 : 1) }
      node.update(type: :plain, reference: nil, children: ['(?:', *branches, ')'])
    end

    # At the end of the input, a backreference succeeds only when its value
    # is empty or unmatched. Negating that test checks for a nonempty value.
    # (1, true) => /(?=[\s\S]*(?![\s\S])(?!\1))/;
    # (1, false) => /(?=[\s\S]*(?![\s\S])\1)/.
    def nonempty_capture_check(reference, nonempty)
      backref = capture_value(reference)
      test = nonempty ? Node.new('(?!', backref, ')') : backref
      Node.new('(?=[\\s\\S]*(?![\\s\\S])', test, ')')
    end

    # /(a)(b)?/ => [2]; /(?:(a)|b)/ => [1].
    def potentially_absent_groups(node = tree, optional = false, reachable_only: false)
      return [] if node.instance_of?(String) || (reachable_only && unmatchable?(node))

      optional ||= node.optional? || node.conditional? ||
        node.negative_assertion?
      groups = optional && node.type == :captured_group ? [node.reference] : []
      children = node.children
      if node.alternation?
        children = children.reject { |child| unmatchable?(child) } if reachable_only
        optional ||= children.length > 1
      end
      children.each do |child|
        groups.concat(potentially_absent_groups(child, optional, reachable_only: reachable_only))
      end
      groups
    end

    # With a generated failure node: /a(?!)/ => true; /(?!)?/ => false,
    # because the failing part can be skipped.
    def unmatchable?(node)
      return node == '(?!)' if node.instance_of?(String)
      return false if node.optional? || node.negative_assertion?

      if node.conditional?
        branches = node.conditional_branches
        branches.length == 2 && branches.all? { |child| unmatchable?(child) }
      elsif node.alternation?
        node.children.all? { |child| unmatchable?(child) }
      else
        node.children.any? { |child| unmatchable?(child) }
      end
    end

    # Make sure the referenced group actually matches by preventing optional
    # groups and alternative branches from skipping it. Returns true if the
    # referenced group is anywhere inside this node, including the node itself.
    # Requiring capture 1: /(?:(a)|b)?/ => /(?:(a)|b(?!))/; returns true.
    def require_group_participation(node, reference)
      return false if node.instance_of?(String)

      children_with_group = node.children.map do |child|
        require_group_participation(child, reference)
      end
      found = node.type == :captured_group && node.reference == reference
      return false unless found || children_with_group.any?

      min_quantify(node)
      if node.children.length > 1 && node.alternation?
        node.children.each.with_index do |branch, i|
          branch << Node.new('(?!)') unless children_with_group[i]
        end
      end
      true
    end

    # After copying capture 1: /(a)(a)\1/ => /(a)(a)history[2,1]/,
    # where "history" is a placeholder for renumbering references later.
    # The two groups start with the same annotation and receive distinct numbers.
    def renumber_captures
      nodes, paths = reference_nodes_with_paths
      candidates = renumber_groups(nodes, paths)
      nodes.each do |node|
        parent = paths[node][-2]
        # A capture history replaces its children when it is renumbered.
        next if parent&.type == :capture_backref

        renumber_reference(node, candidates)
      end
    end

    # Original capture IDs [1, 1, 2] => [1, 2, 3]; candidates for old ID 1
    # are [2, 1], before excluding copies on incompatible paths.
    def renumber_groups(nodes, paths)
      positions = Hash.new { |hash, key| hash[key] = [] }
      capture_paths = {}
      nodes.select { |node| node.type == :captured_group }.each.with_index do |node, index|
        number = index + 1
        positions[node.reference].unshift(number)
        capture_paths[number] = paths[node]
        node.renumber(number)
      end
      lambda do |reference, node|
        positions[reference].reject do |number|
          capture_path = capture_paths[number]
          reference_path = paths[node]
          # Captures from a negative assertion are always unset outside it.
          mutually_exclusive?(capture_path, reference_path) || capture_path.any? do |ancestor|
            ancestor.negative_assertion? && !reference_path.include?(ancestor)
          end
        end
      end
    end

    # For /(a)\1/, collect the capture and reference nodes with their paths
    # from the root; ordinary literal nodes are omitted.
    def reference_nodes_with_paths
      nodes = []
      paths = {}
      tree.walk(trace: true) do |node, event, path|
        next unless event == :enter
        next unless node.reference || [:capture_backref, :capture_conditional].include?(node.type)

        nodes << node
        paths[node] = path.dup
      end
      [nodes, paths]
    end

    # A condition on capture 1, copied into groups 2 and 3, becomes a condition
    # on either copy; a backreference becomes history[3,2].
    def renumber_reference(node, candidates)
      case node.type
      when :backref, :capture_check
        renumber_backreference(node, candidates.call(node.reference, node))
      when :conditional
        references = candidates.call(node.reference, node)
        if references.length == 1
          node.renumber(references.first)
        else
          checks = Node.new(*references.map { |number| Node.new(reference: number) })
          node.update(type: :capture_conditional, reference: nil,
                      children: [checks, *node.conditional_branches])
        end
      when :capture_backref
        references = node.children.flat_map { |child| candidates.call(child.reference, node) }
        node.update(children: references.map { |number| backref(number) })
      when :capture_conditional
        checks = node.children.first
        references = checks.children.flat_map { |child| candidates.call(child.reference, node) }
        checks.update(children: references.map { |number| Node.new(reference: number) })
      end
    end

    # \1 with candidates [3] => \3; with [3, 2] => history[3,2].
    def renumber_backreference(node, references)
      if references.length == 1
        node.renumber(references.first)
      elsif references.empty? && node.type == :capture_check
        node.update(type: :plain, reference: nil, children: [''])
      else
        node.update(type: :capture_backref, reference: nil,
                    children: references.map { |number| backref(number) })
      end
    end

    # 1 => a /\1/ node that must fail if capture 1 did not participate.
    def backref(number)
      Node.new("\\#{number}", reference: number, type: :backref)
    end

    # These references inspect a value and permit an unmatched capture.
    # 1 => a /\1/ node that may match empty when capture 1 did not participate.
    def capture_value(number)
      Node.new("\\#{number}", reference: number, type: :capture_check)
    end

    # (?(1)a|b) => a condition over capture 1's copies, keeping branches a and b
    # for ResolveCaptureReferences to choose using the current capture values.
    def make_condition_dynamic(node)
      checks = Node.new(Node.new(reference: node.reference))
      node.update(type: :capture_conditional, reference: nil, children: [checks, *node.conditional_branches])
    end

    # [/a/, /b/] => /(?:a|b)/; [] => /(?!)/.
    def alternate(branches)
      return Node.new('(?!)') if branches.empty?
      return branches.first if branches.length == 1

      parts = branches.map { |branch| (branch.is_a?(Node) && branch.branch?) ? branch : Node.new(branch, type: :branch) }
      parts.each.with_index { |part, index| part.children.unshift('|') unless index.zero? }
      Node.new('(?:', Node.new(*parts), ')')
    end

    # /(?:a|b)/ => [/(?:a)/, /(?:b)/], preserving wrappers on each choice.
    def split_alternatives(node)
      if node.alternation?
        node.children.map do |branch|
          chosen = branch.with(type: :plain)
          chosen.children.shift if chosen.children.first == '|'
          chosen
        end
      else
        grouped = ['(', '(?:'].include?(node.children.first) && node.children.last == ')'
        return unless grouped || node.children.length == 1

        children = node.children.grep(Node)
        return unless children.length == 1 && !children.first.quantifier

        alternatives = split_alternatives(children.first)
        return unless alternatives

        alternatives.map do |alternative|
          node.with(children: node.children.map { |el| el.equal?(children.first) ? alternative : el.clone })
        end
      end
    end

    # Body /a/ => /(a)/ with a fresh negative capture ID, numbered later.
    def temporary_capture(*children)
      # Negative IDs avoid existing group numbers until renumber_captures runs.
      @temporary_reference ||= -1
      Node.new('(', *children, ')', reference: (@temporary_reference -= 1), type: :captured_group)
    end

    # If capture 1 saved the remaining input before an iteration, emit /(?!\1)/
    # to reject an iteration that leaves the input position unchanged.
    def require_progress(reference)
      Node.new('(?!', capture_value(reference), ')')
    end

    def common_path_length(left, right)
      length = 0
      length += 1 while left[length] && left[length].equal?(right[length])
      length
    end

    # Paths to (a) and \1 in /(a)|\1/ => true; in /(?:(a)|\1)+/ => false,
    # since different iterations can take different branches.
    def mutually_exclusive?(left, right)
      common_length = common_path_length(left, right)
      owner = left[common_length - 1] if common_length > 0
      return false unless owner&.alternation?

      # Different branches can still participate on different loop iterations.
      left[0...common_length].none? { |node| node.repeated? }
    end

    # Visit unbounded loops with their continuation, replacing the first suffix
    # for which the caller supplies a rewrite. Do not descend into repetitions.
    def rewrite_loop_and_tail(node, &block)
      return false unless node.is_a?(Node)
      return false if node.repeated?

      finish = sequence_end(node)
      if finish
        node.children.each.with_index do |child, index|
          next unless child.is_a?(Node) && child.quantifier&.unbounded? && child.quantifier.minimum_at_most_one?

          following = Node.new(*node.children[(index + 1)...finish])
          replacement = yield(child, following)
          next unless replacement

          node.update(children: [*node.children[0...index], replacement, *node.children[finish..-1]])
          return true
        end
      end
      node.children.any? { |child| rewrite_loop_and_tail(child, &block) }
    end

    # /(a(b))/ => /(?:a(?:b))/.
    def without_captures(node)
      copy = node.clone
      copy.walk { |part| part.make_passive if part.type == :captured_group }
      copy
    end

    # /a?/ => true; /a/ => false.
    def may_match_empty?(node)
      match_length(node).min.zero?
    end

    def match_length(node)
      Regexp::Parser.parse(node.to_s).match_length
    end
  end
end
