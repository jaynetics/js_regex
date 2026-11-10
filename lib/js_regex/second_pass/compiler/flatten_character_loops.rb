# frozen_string_literal: true

require_relative 'analysis'
require_relative 'literal_word'

# Greedy runs over distinct single characters have no competing iteration
# boundaries that affect their values. Flattening /(?:(?:(a)|b)+|c)+/ to
# /(?:(a)|b|c)+/ lets capture-retention rules handle the resulting single loop.
class JsRegex::SecondPass::Compiler::FlattenCharacterLoops
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, analysis: nil)
    new(expression, analysis).rewrite(expression)
  end

  def initialize(expression, analysis)
    @analysis = analysis || Compiler::Analysis.new(expression)
  end

  def rewrite(expression)
    return expression if expression.instance_of?(String)

    children = expression.children.map { |child| rewrite(child) }
    result = children == expression.children ? expression : expression.with(children: children)
    if greedy_loop?(result) && @analysis[expression].references.empty?
      original = alternatives(result.children.first)
      branches = original.flat_map do |branch|
        nested = Compiler.unwrap(branch)
        greedy_loop?(nested) && nested.quantity.min == 1 ? alternatives(nested.children.first) : [branch]
      end
      if branches.length > original.length && distinct_characters?(branches)
        choice = Expression.new(:choice, branches.map { |branch| Expression.new(:branch, [branch]) })
        return result.with(children: [Expression.new(:group, [choice])])
      end
    end
    result
  end

  private

  def greedy_loop?(expression)
    !expression.instance_of?(String) && expression.kind == :repeat && expression.quantity.max < 0 &&
      expression.quantity.min <= 1 && expression.quantity.mode == :greedy
  end

  def alternatives(expression)
    expression = Compiler.unwrap(expression)
    expression.kind == :choice ? expression.children : [expression]
  end

  def distinct_characters?(branches)
    words = branches.map { |branch| Compiler::LiteralWord.call(branch) }
    return false unless words.all? { |word| word && word.length == 1 }
    characters = words.map { |word| CharacterSet.of_string(word).case_insensitive }
    characters.combination(2).all? { |left, right| left.disjoint?(right) }
  end
end
