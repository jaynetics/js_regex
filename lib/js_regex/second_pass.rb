# frozen_string_literal: true

class JsRegex
  # Processes converted Nodes in order, sharing tree traversal and capture checks
  # with the individual second-pass steps.
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
      STEPS.each { |step| step.call(tree) }
    end

    STEPS = [
      SubstituteRootLevelKeepMark,
      ExpandBoundedCaptureLoops,
      ExpandNullableCaptures,
      ExpandConstantCaptureLoops,
      PreserveRepeatedCaptures,
      ResolveCaptureReferences,
      GuardMultiplexedBackrefs,
      AlternateConditionalPermutations,
      HandleNonParticipatingBackrefs,
      DelimitBackrefs,
    ]

    private

    attr_accessor :tree

    #
    # Shared helper methods used in multiple subclasses / steps
    #

    def walk(node = tree, trace: false, &block)
      return if node.instance_of?(String)

      trace ? yield(node, :enter) : yield(node)
      node.children.each { |child| walk(child, trace: trace, &block) }
      trace && yield(node, :exit)
    end

    def branch?(node)
      node.is_a?(Node) && node.type == :branch
    end

    def alternation?(node)
      node.is_a?(Node) && node.children.any? && node.children.all? { |child| branch?(child) }
    end

    def repeated?(node)
      node.quantifier && (node.quantifier.max < 0 || node.quantifier.max > 1)
    end

    def sequence_end(node)
      return if alternation?(node) || [:conditional, :capture_conditional].include?(node.type)

      head = node.children.first
      if ['(', '(?:', '(?=', '(?!', '(?<=', '(?<!'].include?(head) && node.children.last == ')'
        node.children.length - 1
      elsif !(head.is_a?(String) && head.start_with?('('))
        node.children.length
      end
    end

    def reference_counts(node)
      counts = Hash.new(0)
      walk(node) { |part| counts[part.reference] += 1 if part.reference && part.type != :captured_group }
      counts
    end

    def required_on_path?(group_path, path)
      group_path && group_path.all? do |ancestor|
        !skippable_scope?(ancestor) || path.include?(ancestor)
      end
    end

    def skippable_scope?(node)
      node.optional? || branch?(node) || ['(?!', '(?<!'].include?(node.children.first)
    end

    # Force a node to occur at least once (unless it is quantified with {0,0}).
    def min_quantify(node)
      return unless node.optional?

      qtf = node.quantifier
      case qtf.max
      when 0 # {0,0}
        node.update(children: ['(?!)', *node.children], quantifier: nil)
      when 1 # any zero_or_one quantifier (?, ??, ?+, {0,1}, {0,1}?)
        node.update(quantifier: nil)
      else
        min_quantifier = qtf.dup
        maximum = qtf.max < 0 ? '' : qtf.max
        min_quantifier.text = "{1,#{maximum}}#{'?' if qtf.reluctant?}"
        node.update(quantifier: min_quantifier)
      end
    end

    # Disable a node while keeping its captures in the source, so existing
    # reference numbers remain valid.
    def null_quantify(node)
      null_quantifier = Regexp::Expression::Quantifier.construct(text: '{0}')
      node.update(quantifier: null_quantifier)
    end

    # At the end of the input, a backreference succeeds only when its value
    # is empty or unmatched. Negating that test checks for a nonempty value.
    def nonempty_capture_check(reference, nonempty)
      backref = capture_value(reference)
      test = nonempty ? Node.new('(?!', backref, ')') : backref
      Node.new('(?=[\\s\\S]*(?![\\s\\S])', test, ')')
    end

    def potentially_absent_groups(node = tree, optional = false)
      return [] if node.instance_of?(String)

      optional ||= node.optional? || [:conditional, :capture_conditional].include?(node.type) ||
        ['(?!', '(?<!'].include?(node.children.first)
      groups = optional && node.type == :captured_group ? [node.reference] : []
      alternatives = node.children.length > 1 &&
        node.children.all? { |child| child.is_a?(Node) && child.type == :branch }
      node.children.each do |child|
        groups.concat(potentially_absent_groups(child, optional || alternatives))
      end
      groups
    end

    def unmatchable?(node)
      return node == '(?!)' if node.is_a?(String)
      return false if node.optional? || ['(?!', '(?<!'].include?(node.children.first)

      if [:conditional, :capture_conditional].include?(node.type)
        branches = node.type == :conditional ? node.children[1...-1] : node.children[1..-1]
        branches.length == 2 && branches.all? { |child| unmatchable?(child) }
      elsif alternation?(node)
        node.children.all? { |child| unmatchable?(child) }
      else
        node.children.any? { |child| unmatchable?(child) }
      end
    end

    # Make sure the referenced group actually matches by preventing optional
    # groups and alternative branches from skipping it. Returns true if the
    # referenced group is anywhere inside this node, including the node itself.
    def require_group_participation(node, reference)
      return false if node.instance_of?(String)

      children_with_group = node.children.map do |child|
        require_group_participation(child, reference)
      end
      found = node.type == :captured_group && node.reference == reference
      return false unless found || children_with_group.any?

      min_quantify(node)
      if node.children.length > 1 && node.children.all? { |child| branch?(child) }
        node.children.each.with_index do |branch, i|
          branch << Node.new('(?!)') unless children_with_group[i]
        end
      end
      true
    end

    def renumber_captures
      nodes, paths = reference_nodes_with_paths
      positions = Hash.new { |hash, key| hash[key] = [] }
      capture_paths = {}
      nodes.select { |node| node.type == :captured_group }.each.with_index do |node, index|
        number = index + 1
        positions[node.reference].unshift(number)
        capture_paths[number] = paths[node]
        node.update(reference: number)
      end
      candidates = lambda do |reference, node|
        positions[reference].reject { |number| mutually_exclusive?(capture_paths[number], paths[node]) }
      end
      nodes.each do |node|
        parent = paths[node][-2]
        # A history replaces its children itself; those old references must
        # not be renumbered again after their parent has been updated.
        next if parent && parent.type == :capture_backref

        renumber_reference(node, candidates)
      end
    end

    def reference_nodes_with_paths
      nodes = []
      paths = {}
      path = []
      walk(trace: true) do |node, event|
        if event == :enter
          path.push(node)
          if node.reference || [:capture_backref, :capture_conditional].include?(node.type)
            nodes << node
            paths[node] = path.dup
          end
        else
          path.pop
        end
      end
      [nodes, paths]
    end

    def renumber_reference(node, candidates)
      case node.type
      when :backref, :capture_check
        renumber_backreference(node, candidates.call(node.reference, node))
      when :conditional
        references = candidates.call(node.reference, node)
        if references.length == 1
          node.update(reference: references.first)
        else
          checks = Node.new(*references.map { |number| Node.new(reference: number) })
          node.update(type: :capture_conditional, reference: nil,
                      children: [checks, *node.children[1...-1]])
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

    def renumber_backreference(node, references)
      if references.length == 1
        node.update(reference: references.first, children: ["\\#{references.first}"])
      elsif references.empty? && node.type == :capture_check
        node.update(type: :plain, reference: nil, children: [''])
      else
        node.update(type: :capture_backref, reference: nil,
                    children: references.map { |number| backref(number) })
      end
    end

    def backref(number)
      Node.new("\\#{number}", reference: number, type: :backref)
    end

    # These references inspect a value and permit an unmatched capture.
    def capture_value(number)
      Node.new("\\#{number}", reference: number, type: :capture_check)
    end

    def make_condition_dynamic(node)
      checks = Node.new(Node.new(reference: node.reference))
      node.update(type: :capture_conditional, reference: nil, children: [checks, *node.children[1...-1]])
    end

    def alternate(branches)
      return Node.new('(?!)') if branches.empty?
      return branches.first if branches.length == 1

      parts = branches.map { |branch| branch?(branch) ? branch : Node.new(branch, type: :branch) }
      parts.each.with_index { |part, index| part.children.unshift('|') unless index.zero? }
      Node.new('(?:', Node.new(*parts), ')')
    end

    def temporary_capture(*children)
      # Negative IDs avoid existing group numbers until renumber_captures runs.
      @temporary_reference ||= 0
      Node.new('(', *children, ')', reference: (@temporary_reference -= 1), type: :captured_group)
    end

    def require_progress(reference)
      Node.new('(?!', capture_value(reference), ')')
    end

    def mutually_exclusive?(left, right)
      common_length = 0
      common_length += 1 while left[common_length] && left[common_length].equal?(right[common_length])
      owner = left[common_length - 1] if common_length > 0
      return false unless alternation?(owner)

      # Different branches can still participate on different loop iterations.
      left[0...common_length].none? { |node| repeated?(node) }
    end
  end
end
