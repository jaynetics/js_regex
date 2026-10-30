# frozen_string_literal: true

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
      branch
      capture_backref
      capture_check
      capture_conditional
      captured_group
      conditional
      dropped
      keep_mark
      multiplex_backref
      plain
    ].freeze

    def initialize(*children, reference: nil, type: :plain, nonempty: false, nullable: false)
      self.children = children
      self.reference = reference
      self.type = type
      @nonempty = nonempty
      @nullable = nullable
    end

    def initialize_copy(*)
      self.children = children.map(&:clone)
    end

    # Copy the metadata without cloning children that the caller will replace.
    def copy_with_children(*replacements)
      self.class.new(*replacements, reference: reference, type: type,
                     nonempty: nonempty?, nullable: nullable?).update(quantifier: quantifier)
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
      when :backref, :branch, :capture_check, :captured_group, :plain
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
      self.reference  = attrs.fetch(:reference)  if attrs.key?(:reference)
      self
    end

    def optional?
      quantifier&.min == 0
    end

    # Keep numeric reference text in sync with its annotation. Captures and
    # unresolved conditions only store the number in their annotation.
    def renumber(number)
      self.reference = number
      case type
      when :backref, :capture_check then children[0] = "\\#{number}"
      end
      self
    end

    def negative_assertion?
      head = children.first
      head == '(?!' || head == '(?<!'
    end

    def positive_assertion?
      head = children.first
      head.is_a?(String) && (head.start_with?('(?=') || head == '(?<=')
    end

    def atomic?
      # Atomic groups are emitted as a lookahead followed by a backreference.
      children.first == '(?:(?='
    end

    def nonempty?
      @nonempty
    end

    # The body can match empty at any position, without relying on assertions
    # or backreferences. Neither flag being set means the body is uncertain.
    def nullable?
      @nullable
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
