# frozen_string_literal: true

class JsRegex::SecondPass::Compiler
  Unsupported = Class.new(StandardError)

  # A logical capture survives duplication; each emitted group has its own
  # occurrence. Neither identity depends on the final JavaScript group number.
  class Capture
    attr_reader :source_id

    def initialize(source_id = nil)
      @source_id = source_id
      freeze
    end
  end

  class Occurrence
    attr_reader :capture

    def initialize(capture = Capture.new)
      @capture = capture
      freeze
    end
  end

  # Own the quantifier data rather than sharing the parser's mutable object.
  class Quantity
    attr_reader :text, :min, :max, :mode

    def initialize(quantifier)
      @text = quantifier.text.dup.freeze
      @min = quantifier.min
      @max = quantifier.max
      @mode = quantifier.possessive? ? :possessive : (quantifier.reluctant? ? :lazy : :greedy)
      freeze
    end

    COMMON = %w[* *? + +? ? ?? {0}].to_h do |text|
      [text, new(Regexp::Expression::Quantifier.construct(text: text))]
    end.freeze

    def self.from_text(text)
      COMMON.fetch(text) { new(Regexp::Expression::Quantifier.construct(text: text)) }
    end
  end

  class Expression
    KINDS = %i[
      sequence choice branch omitted_branch group capture repeat native_repeat atomic absence opaque
      lookahead negative_lookahead lookbehind negative_lookbehind
      backreference value history multiplex conditional capture_conditional
      keep dropped
    ].freeze

    attr_reader :kind, :children, :reference, :quantity, :nonempty, :nullable

    def initialize(kind, children = [], reference: nil, quantity: nil, nonempty: false, nullable: false)
      raise ArgumentError, "unknown expression kind: #{kind}" unless KINDS.include?(kind)

      @kind = kind
      @children = children.map do |child|
        child.instance_of?(String) && !child.frozen? ? child.dup.freeze : child
      end.freeze
      @reference = reference
      @quantity = quantity
      @nonempty = nonempty
      @nullable = nullable
      freeze
    end

    # Rebuilding an ancestor keeps capture bindings intact. To duplicate a
    # capture-bearing subtree in the output, use Compiler.copy instead.
    def with(children: self.children, reference: self.reference, nullable: self.nullable)
      self.class.new(kind, children, reference: reference, quantity: quantity,
                     nonempty: nonempty, nullable: nullable)
    end
  end

  def self.walk(expression, &block)
    return if expression.instance_of?(String)

    yield expression
    expression.children.each { |child| walk(child, &block) }
  end

  # Inspect through passive, single-child wrappers without crossing a capture,
  # assertion, or repetition boundary. Keep literal leaves wrapped as expressions.
  def self.unwrap(expression)
    while [:sequence, :group, :branch].include?(expression.kind) && expression.children.one? &&
          !expression.children.first.instance_of?(String)
      expression = expression.children.first
    end
    expression
  end

  # Captures separated only by passive single-child groups close over the same
  # text. Stop at a choice, quantifier, assertion, or additional sequence part.
  def self.capture_chain(expression)
    captures = []
    while expression.kind == :capture
      captures << expression
      break unless expression.children.one? && !expression.children.first.instance_of?(String)
      expression = unwrap(expression.children.first)
    end
    captures
  end

  # Rebind references to captures defined inside the copy, including forward
  # references. References to captures outside it retain their original binding.
  def self.copy(expression)
    occurrences = {}
    walk(expression) do |part|
      if part.kind == :capture
        occurrences[part.reference] = Occurrence.new(part.reference.capture)
      end
    end
    rebind(expression, occurrences)
  end

  def self.rebind(expression, occurrences)
    return expression if expression.instance_of?(String)

    children = expression.children.map { |child| rebind(child, occurrences) }
    reference = occurrences.fetch(expression.reference, expression.reference)
    return expression if children == expression.children && reference.equal?(expression.reference)

    expression.with(children: children, reference: reference)
  end
end
