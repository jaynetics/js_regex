# frozen_string_literal: true

class JsRegex
  #
  # Converter#convert result. Represents a branch or leaf node with an optional
  # quantifier as well as type and reference annotations for SecondPass.
  #
  class Node
    require_relative 'error'
    Dir[File.join(__dir__, 'node', '*.rb')].sort.each { |f| require f }

    ATTRIBUTES = %i[
      children
      marked_nonempty
      nullable
      quantifier
      reference
      type
    ].freeze

    attr_reader(*ATTRIBUTES)

    REFERENCE_TYPES = %i[
      backref
      capture_backref
      capture_check
      capture_conditional
      conditional
      multiplex_backref
    ].freeze

    REFERENCE_TYPES_MAP = REFERENCE_TYPES.to_h { |k| [k, true] }.freeze

    TYPES = (REFERENCE_TYPES + %i[
      branch
      captured_group
      dropped
      keep_mark
      plain
    ]).freeze

    TYPES_MAP = TYPES.to_h { |k| [k, true] }.freeze

    def initialize(*children, reference: nil, type: :plain, marked_nonempty: false, nullable: false, quantifier: nil)
      self.children = children
      self.reference = reference
      self.type = type
      self.marked_nonempty = marked_nonempty
      self.nullable = nullable
      self.quantifier = quantifier
    end

    def <<(node)
      children << node
      self
    end

    def initialize_copy(*)
      super
      self.children = children.map(&:clone)
    end

    private

    TypeError = Class.new(::TypeError).extend(JsRegex::Error)

    def type=(arg)
      arg.nil? || TYPES_MAP[arg] ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @type = arg
    end

    def children=(arg)
      arg.class == Array ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @children = arg
    end

    def quantifier=(arg)
      arg.nil? || arg.class == Quantifier ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @quantifier = arg
    end

    def reference=(arg)
      arg.nil? || arg.is_a?(Numeric) ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @reference = arg
    end

    def marked_nonempty=(arg)
      arg == true || arg == false ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @marked_nonempty = arg
    end

    def nullable=(arg)
      arg == true || arg == false ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @nullable = arg
    end
  end
end
