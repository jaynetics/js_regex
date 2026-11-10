# frozen_string_literal: true

require_relative 'model'

module JsRegex::SecondPass::Compiler::LiteralWord
  # Conservative structural recognition; never render and reparse a subtree.
  def self.call(expression)
    if expression.instance_of?(String)
      return expression if expression.each_char.none? { |char| '\\.^$|?*+()[]{}'.include?(char) }
      return
    end
    case expression.kind
    when :sequence, :group, :branch, :capture
      words = expression.children.map { |child| call(child) }
      words.join if words.none?(&:nil?)
    when :repeat
      quantity = expression.quantity
      return '' if quantity.max.zero?
      return unless quantity.min == quantity.max
      body = call(expression.children.first)
      body * quantity.min if body
    when :dropped, :omitted_branch then ''
    end
  end
end
