# frozen_string_literal: true

require_relative 'analysis'

class JsRegex::SecondPass::Compiler::CharacterFacts
  def initialize(analysis)
    @analysis = analysis
    @first = {}
    @alphabets = {}
    @nonempty = {}
    @widths = {}
    @fragments = {}
  end

  # A conservative set of first consumed characters, including characters after
  # nullable prefixes. Unknown assertions and compound fragments remain unknown.
  def first(expression)
    return @first[expression] if @first.key?(expression)
    @first[expression] = first_characters(expression)
  rescue Regexp::Parser::Error, CharacterSet::ExpressionConverter::Error
    @first[expression] = nil
  end

  def regular?(expression)
    return regular_fragment?(parse(expression)) if expression.instance_of?(String)
    if expression.kind == :opaque && expression.children.one? && expression.children.first.instance_of?(String)
      return regular?(expression.children.first)
    end
    return false unless [:sequence, :branch, :group, :capture, :repeat, :choice].include?(expression.kind)
    return false if expression.quantity && expression.quantity.mode == :possessive

    expression.children.all? { |child| regular?(child) }
  rescue Regexp::Parser::Error
    false
  end

  # Include characters anywhere in the body, not only at its initial position.
  # This proves that shortening a skipped iteration cannot expose a capture's
  # starting character. Assertions and unknown fragments invalidate the proof.
  def alphabet(expression)
    return @alphabets[expression] if @alphabets.key?(expression)
    @alphabets[expression] =
      if !regular?(expression)
        nil
      elsif expression.instance_of?(String)
        CharacterSet.of_expression(parse(expression))
      else
        sets = expression.children.map { |child| alphabet(child) }
        sets.reduce(:|) || CharacterSet.of_string('') if sets.all?
      end
  rescue Regexp::Parser::Error, CharacterSet::ExpressionConverter::Error
    @alphabets[expression] = nil
  end

  def nonempty?(expression)
    return @nonempty[expression] if @nonempty.key?(expression)
    @nonempty[expression] = consumes?(expression)
  rescue Regexp::Parser::Error
    @nonempty[expression] = false
  end

  def fixed_width(expression)
    return @widths[expression] if @widths.key?(expression)
    @widths[expression] = width(expression)
  rescue Regexp::Parser::Error
    @widths[expression] = nil
  end

  # Structural proof that the first successful path is unconditionally empty.
  def empty_first?(expression)
    return expression.empty? if expression.instance_of?(String)

    case expression.kind
    when :sequence, :group, :branch, :capture
      expression.children.all? { |child| empty_first?(child) }
    when :choice
      first = expression.children.find { |child| child.kind != :omitted_branch }
      first && empty_first?(first)
    when :repeat
      quantity = expression.quantity
      quantity.max.zero? || (quantity.min.zero? && quantity.mode == :lazy) || empty_first?(expression.children.first)
    when :dropped then true
    else false
    end
  end

  # All consuming paths must precede the empty path. A nullable earlier arm or
  # a lazy nullable component can interleave them and invalidates this proof.
  def empty_last?(expression)
    return expression.empty? if expression.instance_of?(String)

    case expression.kind
    when :sequence, :group, :branch, :capture
      expression.children.all? { |child| empty_last?(child) }
    when :choice
      branches = expression.children.reject { |child| child.kind == :omitted_branch }
      first_empty = branches.index { |child| !nonempty?(child) }
      first_empty && empty_last?(branches[first_empty]) &&
        branches.drop(first_empty + 1).all? { |child| fixed_width(child) == 0 }
    when :repeat
      quantity = expression.quantity
      quantity.max.zero? || (quantity.mode == :greedy &&
        ((quantity.min.zero? && nonempty?(expression.children.first)) || empty_last?(expression.children.first)))
    when :dropped then true
    else false
    end
  end

  private

  def width(expression)
    if expression.instance_of?(String)
      length = parse(expression).match_length
      return length.min if length.fixed?
      return
    end
    if expression.kind == :repeat
      quantity = expression.quantity
      return unless quantity.min == quantity.max
      inner = fixed_width(expression.children.first)
      return inner * quantity.min if inner
      return
    end
    return unless [:sequence, :branch, :group, :capture, :choice].include?(expression.kind)
    widths = expression.children.map { |child| fixed_width(child) }
    return if widths.any?(&:nil?)
    expression.kind == :choice ? (widths.first if widths.uniq.one?) : widths.sum
  end

  def consumes?(expression)
    return true if @analysis[expression].empty == :never
    return parse(expression).match_length.min > 0 if expression.instance_of?(String)
    case expression.kind
    when :sequence, :branch, :group, :capture then expression.children.any? { |child| nonempty?(child) }
    when :opaque then regular?(expression) && expression.children.one? && nonempty?(expression.children.first)
    when :choice then !expression.children.empty? && expression.children.all? { |child| nonempty?(child) }
    when :repeat then expression.quantity.min > 0 && nonempty?(expression.children.first)
    else false
    end
  end

  def first_characters(expression)
    if expression.instance_of?(String)
      return CharacterSet.of_string(expression[0]) if @analysis[expression].empty == :never
      return CharacterSet.of_expression(parse(expression)) unless expression.empty?
      return CharacterSet.of_string('')
    end
    return first(expression.children.first) if expression.kind == :repeat
    if expression.kind == :opaque
      return first(expression.children.first) if expression.children.one? && expression.children.first.instance_of?(String)
      return
    end
    return unless [:sequence, :branch, :group, :capture, :choice].include?(expression.kind)

    sets = []
    expression.children.each do |child|
      characters = first(child)
      return nil unless characters
      sets << characters
      break if expression.kind != :choice && nonempty?(child)
    end
    sets.reduce(:|) || CharacterSet.of_string('')
  end

  # Parse leaves once, never rendered generated subtrees. The character union
  # may overestimate the initial set, which only prevents a disjointness proof.
  def parse(fragment)
    @fragments[fragment] ||= Regexp::Parser.parse(fragment)
  end

  def regular_fragment?(expression)
    return false unless [:expression, :group, :literal, :meta, :escape, :property, :nonproperty, :set, :type].include?(expression.type)
    return false if expression.type == :group && expression.token != :passive
    return false if expression.quantifier&.possessive?

    expression.terminal? || expression.expressions.all? { |child| regular_fragment?(child) }
  end
end
