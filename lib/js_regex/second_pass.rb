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
      ResolveCaptureConditionals,
      ResolveCaptureBackrefs,
      GuardMultiplexedBackrefs,
      AlternateConditionalPermutations,
      HandleNonParticipatingBackrefs,
      DelimitBackrefs,
    ]

    private

    attr_accessor :tree

    def walk(node = tree, trace: false, &block)
      return if node.instance_of?(String)

      trace ? yield(node, :enter) : yield(node)
      node.children.each { |child| walk(child, trace: trace, &block) }
      trace && yield(node, :exit)
    end

    # At the end of the input, only an empty/unmatched backreference can
    # succeed. Negating that test detects a participating nonempty capture.
    def capture_check(reference, present)
      backref = Node.new("\\#{reference}", reference: reference, type: :capture_check)
      test = present ? Node.new('(?!', backref, ')') : backref
      Node.new('(?=[\\s\\S]*(?![\\s\\S])', test, ')')
    end

    def potentially_absent_groups(node = tree, optional = false)
      return [] if node.instance_of?(String)

      optional ||= node.optional? || node.type == :conditional ||
        ['(?!', '(?<!'].include?(node.children.first)
      groups = optional && node.type == :captured_group ? [node.reference] : []
      alternatives = node.children.length > 1 &&
        node.children.all? { |child| child.is_a?(Node) && child.type == :branch }
      node.children.each do |child|
        groups.concat(potentially_absent_groups(child, optional || alternatives))
      end
      groups
    end
  end
end
