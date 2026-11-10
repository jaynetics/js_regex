# frozen_string_literal: true

# Final lexical cleanup, after every capture has its emitted number. Track the
# previous numeric reference across empty nodes without rendering subtrees.
class JsRegex::SecondPass::Compiler::DelimitReferences
  def self.call(tree)
    new.call(tree)
  end

  def call(tree)
    @pending = nil
    @insertions = []
    visit(tree)
    @insertions.each { |reference| reference.children.insert(1, '(?:)') }
    tree
  end

  private

  def visit(node)
    return if node.dropped?

    node.children.each.with_index do |child, index|
      if child.instance_of?(String)
        text(child)
        if index.zero? && [:backref, :capture_check].include?(node.type) && /\A\\[0-9]+\z/.match?(child)
          @pending = node
        end
      else
        visit(child)
      end
    end
    text(node.quantifier.to_s)
  end

  def text(string)
    return if string.empty?

    @insertions << @pending if @pending && /\A[0-9]/.match?(string)
    @pending = nil
  end
end
