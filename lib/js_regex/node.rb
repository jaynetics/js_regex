# frozen_string_literal: true

class JsRegex
  #
  # Converter#convert result. Represents a branch or leaf node with an optional
  # quantifier as well as type and reference annotations for SecondPass.
  #
  class Node
    attr_reader :children, :quantifier, :reference, :type

    TYPES = %i[
      backref_num
      captured_group
      conditional
      dropped
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
      when :backref_num, :captured_group, :plain
        children.join << quantifier.to_s
      else
        raise TypeError, "#{type} must be substituted before stringification"
      end
    end

    def update(attrs)
      self.children   = attrs.fetch(:children)   if attrs.key?(:children)
      self.quantifier = attrs.fetch(:quantifier) if attrs.key?(:quantifier)
      self.type       = attrs.fetch(:type)       if attrs.key?(:type)
    end

    private

    attr_writer :children, :reference, :quantifier, :type
  end
end
