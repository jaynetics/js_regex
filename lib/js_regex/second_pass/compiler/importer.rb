# frozen_string_literal: true

require_relative 'model'

class JsRegex::SecondPass::Compiler::Importer
  Compiler = JsRegex::SecondPass::Compiler
  Node = JsRegex::Node

  WRAPPERS = {
    '(?:' => :group, '(?=' => :lookahead, '(?!' => :negative_lookahead,
    '(?<=' => :lookbehind, '(?<!' => :negative_lookbehind,
  }.freeze

  TYPES = {
    captured_group: :capture, backref: :backreference, capture_check: :value,
    capture_backref: :history, multiplex_backref: :multiplex,
    conditional: :conditional, capture_conditional: :capture_conditional,
    branch: :branch, keep_mark: :keep, dropped: :dropped,
  }.freeze

  def self.call(tree)
    new.read(tree)
  end

  def initialize
    @occurrences = {}
    @definitions = {}
  end

  def read(node)
    return node.dup.freeze if node.instance_of?(String)

    reference = occurrence(node.reference) if node.reference
    if node.type == :captured_group
      raise ArgumentError, "duplicate input capture: #{node.reference}" if @definitions[reference]

      @definitions[reference] = true
    end
    kind, children = contents(node)
    expression = Compiler::Expression.new(kind, children.map { |child| read(child) },
                                           reference: reference, nonempty: node.nonempty?, nullable: node.nullable?)
    return expression unless node.quantifier

    Compiler::Expression.new(:repeat, [expression], quantity: Compiler::Quantity.new(node.quantifier))
  end

  private

  def occurrence(number)
    @occurrences[number] ||= Compiler::Occurrence.new(Compiler::Capture.new(number))
  end

  def contents(node)
    children = node.children
    case node.type
    when :captured_group, :conditional
      [TYPES.fetch(node.type), children[1...-1]]
    when :backref, :capture_check
      # Reference text is reconstructed from the binding at emission. Preserve
      # any suffix, such as a numeric-reference delimiter, without interpreting it.
      [TYPES.fetch(node.type), children.drop(1)]
    when :branch
      if !children.empty? && children.all? { |child| child.is_a?(Node) && child.dropped? }
        [:omitted_branch, children]
      else
        [:branch, children.first == '|' ? children.drop(1) : children]
      end
    when :plain
      plain_contents(children)
    else
      [TYPES.fetch(node.type), children]
    end
  end

  def plain_contents(children)
    if !children.empty? && children.all? { |child| child.is_a?(Node) && child.type == :branch }
      [:choice, children]
    elsif children.length == 5 && children.first == '(?:(?=' && children[2] == ')' && children.last == ')'
      [:atomic, [children[1], children[3]]]
    elsif children.length == 3 && children.first == '(?:(?:(?!' &&
          children.last.instance_of?(String) && children.last.start_with?(')(?:.|\\n))*')
      [:absence, children.drop(1)]
    elsif children.length >= 2 && WRAPPERS.key?(children.first) && children.last == ')'
      [WRAPPERS.fetch(children.first), children[1...-1]]
    elsif children.first.instance_of?(String) && children.first.start_with?('(')
      # Unrecognized compound converter fragments remain boundaries.
      # Their embedded children are still traversable for capture numbering.
      [:opaque, children]
    else
      [:sequence, children]
    end
  end
end
