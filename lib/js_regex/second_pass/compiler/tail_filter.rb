# frozen_string_literal: true

require_relative 'character_facts'

# Reject impossible continuations before exploring equivalent loop partitions.
# This recognizes a superset of the tail's language: values may vary, capture
# participation is ignored, and assertions impose no additional restrictions.
class JsRegex::SecondPass::Compiler::TailFilter
  Compiler = JsRegex::SecondPass::Compiler
  ANY = '[\\s\\S]*'

  def initialize(analysis)
    @analysis = analysis
    @characters = Compiler::CharacterFacts.new(analysis)
  end

  def call(tail)
    pattern = sequence([ANY, source(tail)])
    Compiler::Expression.new(:lookahead, [pattern]) unless pattern == ANY
  end

  private

  def source(expression)
    if expression.instance_of?(String)
      return expression if ['^', '$'].include?(expression) || @characters.regular?(expression)
      return ANY
    end

    case expression.kind
    when :sequence, :branch
      sequence(expression.children.map { |child| source(child) })
    when :group, :capture
      body = sequence(expression.children.map { |child| source(child) })
      body.empty? || body == ANY ? body : '(?:' + body + ')'
    when :repeat, :native_repeat
      return '' if expression.quantity.max.zero?
      body = source(expression.children.first)
      return ANY if body == ANY
      text = expression.quantity.text
      text = text[0...-1] if expression.quantity.mode == :possessive
      '(?:' + body + ')' + text
    when :backreference
      capture = @analysis.captures.fetch(expression.reference)
      capture.nonempty && @characters.regular?(capture) ? source(capture) : ANY
    when :choice, :history, :multiplex, :conditional, :capture_conditional
      children = expression.kind == :capture_conditional ? expression.children.drop(1) : expression.children
      parts = children.map { |child| source(child) }
      parts << '' if [:conditional, :capture_conditional].include?(expression.kind) && children.one?
      parts.include?(ANY) ? ANY : '(?:' + parts.join('|') + ')'
    when :atomic then source(expression.children.first)
    when :lookahead, :negative_lookahead, :lookbehind, :negative_lookbehind, :dropped, :omitted_branch, :keep then ''
    else ANY
    end
  end

  def sequence(parts)
    parts.reject(&:empty?).each_with_object([]) do |part, result|
      result << part unless part == ANY && result.last == ANY
    end.join
  end
end
