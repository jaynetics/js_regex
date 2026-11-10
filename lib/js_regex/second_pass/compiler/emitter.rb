# frozen_string_literal: true

require_relative 'model'

class JsRegex::SecondPass::Compiler::Emitter
  Compiler = JsRegex::SecondPass::Compiler
  Node = JsRegex::Node

  WRAPPERS = {
    group: '(?:', capture: '(', conditional: '(?:', lookahead: '(?=',
    negative_lookahead: '(?!', lookbehind: '(?<=', negative_lookbehind: '(?<!',
  }.freeze

  TYPES = {
    capture: :captured_group, backreference: :backref, value: :capture_check,
    history: :capture_backref, multiplex: :multiplex_backref,
    conditional: :conditional, capture_conditional: :capture_conditional,
    branch: :branch, omitted_branch: :branch, keep: :keep_mark, dropped: :dropped,
  }.freeze

  def self.call(expression, compact: false)
    new(expression, compact).emit(expression)
  end

  def initialize(expression, compact = false)
    @numbers = {}
    @compact = compact
    number_captures(expression)
  end

  def emit(expression)
    return expression.dup if expression.instance_of?(String)

    # These children already provide a quantifiable group boundary. Repeated
    # children and assertions still need their wrapper: removing it could
    # overwrite a quantifier or produce invalid Unicode-mode JS syntax.
    if @compact && expression.kind == :group && !expression.reference && expression.children.one?
      child = expression.children.first
      return emit(child) if !child.instance_of?(String) && [:group, :capture, :atomic].include?(child.kind)
    end

    if [:repeat, :native_repeat].include?(expression.kind)
      quantity = Regexp::Expression::Quantifier.construct(text: expression.quantity.text.dup)
      return emit(expression.children.fetch(0)).update(quantifier: quantity)
    end

    if expression.reference
      reference = @numbers.fetch(expression.reference) do
        raise ArgumentError, 'reference has no emitted capture; lower it before emission'
      end
    end
    children = expression.children.map { |child| emit(child) }
    children = wrap(expression, children, reference)
    Node.new(*children, type: TYPES.fetch(expression.kind, :plain), reference: reference,
                       nonempty: expression.nonempty, nullable: expression.nullable)
  end

  private

  def number_captures(expression)
    return if expression.instance_of?(String) || expression.kind == :dropped

    if expression.kind == :capture
      occurrence = expression.reference
      raise ArgumentError, 'capture requires an occurrence' unless occurrence
      raise ArgumentError, 'capture occurrence emitted twice; copy its subtree first' if @numbers.key?(occurrence)

      @numbers[occurrence] = @numbers.length + 1
    end
    expression.children.each { |child| number_captures(child) }
  end

  def wrap(expression, children, reference)
    kind = expression.kind
    return [WRAPPERS.fetch(kind), *children, ')'] if WRAPPERS.key?(kind)

    case kind
    when :atomic
      ['(?:(?=', children.fetch(0), ')', children.fetch(1), ')']
    when :absence
      ['(?:(?:(?!', *children]
    when :backreference, :value
      ["\\#{reference}", *children]
    when :choice
      kept = false
      children.each.with_index do |branch, index|
        next if expression.children[index].kind == :omitted_branch

        branch.children.unshift('|') if kept
        kept = true
      end
    else
      children
    end
  end
end
