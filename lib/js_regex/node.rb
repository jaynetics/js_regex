class JsRegex
  #
  # Converter#convert result. Represents a branch or leaf node with an optional
  # quantifier as well as type and reference annotations for SecondPass.
  #
  class Node
    require_relative 'error'

    attr_reader :children, :quantifier, :reference, :type

    TYPES = %i[
      backref
      captured_group
      conditional
      dropped
      keep_mark
      plain
    ].freeze

    def initialize(*children, reference: nil, type: :plain)
      self.children = children
      self.reference = reference
      self.type = type
    end

    def initialize_copy(*)
      self.children = children.map(&:clone)
    end

    def transform(&block)
      children.map!(&block)
      self
    end

    def <<(node)
      children << node
      self
    end

    def dropped?
      # keep everything else, including empty or depleted capturing groups
      # so as not to not mess with reference numbers (e.g. backrefs)
      type.equal?(:dropped)
    end

    def to_s
      case type
      when :dropped
        ''
      when :backref, :captured_group, :plain
        children.join << quantifier.to_s
      else
        raise TypeError.new(
          "#{type} must be substituted before stringification"
        ).extend(JsRegex::Error)
      end
    end

    def update(attrs)
      self.children   = attrs.fetch(:children)   if attrs.key?(:children)
      self.quantifier = attrs.fetch(:quantifier) if attrs.key?(:quantifier)
      self.type       = attrs.fetch(:type)       if attrs.key?(:type)
      self
    end

    private

    TypeError = Class.new(::TypeError).extend(JsRegex::Error)

    def type=(arg)
      arg.nil? || TYPES.include?(arg) ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @type = arg
    end

    def children=(arg)
      arg.class == Array ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @children = arg
    end

    def quantifier=(arg)
      arg.nil? || arg.class == Regexp::Expression::Quantifier ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @quantifier = arg
    end

    def reference=(arg)
      arg.nil? || arg.is_a?(Numeric) ||
        raise(TypeError, "unsupported type #{arg.class} for #{__method__}")
      @reference = arg
    end
  end
end
