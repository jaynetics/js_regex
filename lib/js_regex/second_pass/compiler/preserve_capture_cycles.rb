# frozen_string_literal: true

require_relative 'analysis'
require_relative 'character_facts'
require_relative 'capture_histories'

# Group each capture update with intervening skipping iterations. Disjoint
# starting characters or a required adjacent reference establish when this
# regrouping preserves the original order of competing matches.
class JsRegex::SecondPass::Compiler::PreserveCaptureCycles
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression
  attr_reader :split_captures

  def self.call(expression, analysis: nil)
    pass = new(expression, analysis)
    result = pass.rewrite(expression)
    Compiler::CaptureHistories.call(result, pass.split_captures)
  end

  def initialize(expression, analysis)
    @analysis = analysis || Compiler::Analysis.new(expression)
    @references = @analysis[expression].references
    @characters = Compiler::CharacterFacts.new(@analysis)
    @split_captures = []
  end

  def rewrite(expression, following = nil)
    return expression if expression.instance_of?(String)

    replacement = rewrite_loop(expression, following)
    return replacement if replacement

    sequence = [:sequence, :branch, :group, :capture].include?(expression.kind)
    children = expression.children.each_with_index.map do |child, index|
      rewrite(child, sequence ? expression.children[index + 1] : nil)
    end
    children == expression.children ? expression : expression.with(children: children)
  end

  private

  def rewrite_loop(expression, following)
    return unless expression.kind == :repeat
    quantity = expression.quantity
    return unless quantity.max < 0 && quantity.min <= 1 && quantity.mode != :possessive

    body = Compiler.unwrap(expression.children.first)
    wrappers = []
    while body.kind == :capture && body.children.one?
      wrappers << body
      body = Compiler.unwrap(body.children.first)
    end
    return unless body.kind == :choice && body.children.length >= 2
    branches = body.children.map { |branch| Compiler.unwrap(branch) }
    capture = branches.find do |branch|
      branch.kind == :capture && branch.nonempty && @references.fetch(branch.reference, 0) > 0
    end
    return unless capture
    return unless @analysis[body].references.empty?
    return unless (@analysis[body].definitions - [capture.reference]).all? { |ref| @references.fetch(ref, 0).zero? }
    skipping = branches.reject { |branch| branch.equal?(capture) }
    skipped = if skipping.length == 1
                skipping.first
              else
                alternatives = skipping.map { |part| Expression.new(:branch, [part]) }
                Expression.new(:group, [Expression.new(:choice, alternatives)])
              end

    left = @characters.first(capture)
    sets = skipping.map { |part| @characters.first(part) }
    right = sets.reduce(:|) if sets.all?
    # Conservatively fold even case-sensitive input. Unicode case equivalence
    # includes more than String#downcase (for example, s and the long s).
    disjoint = left && right && left.case_insensitive.disjoint?(right.case_insensitive)
    required = following && !following.instance_of?(String) && following.kind == :backreference &&
      following.reference.equal?(capture.reference)
    # For a required adjacent reference, a matching retained value would also
    # match the regular capture body. This permits update cycles even with
    # overlapping branches. Assertions and atomic constructs invalidate that
    # implication and therefore remain outside this rule.
    edge = branches.first.equal?(capture) || branches.last.equal?(capture)
    return unless disjoint || (required && right && edge && @characters.regular?(capture))
    # An absent-capture arm must not shorten a variable skipping iteration before
    # the original loop would try a later capturing iteration. A required value
    # eliminates that arm; fixed-width skips make its splits unique. Greedy
    # loops may also vary skip widths if no split can expose a capturing start.
    if !required && @characters.fixed_width(skipped).nil?
      alphabet = @characters.alphabet(skipped) if quantity.mode == :greedy
      return unless left && alphabet && left.case_insensitive.disjoint?(alphabet.case_insensitive)
    end

    lazy = quantity.mode == :lazy
    capture_first = branches.first.equal?(capture)
    @split_captures |= wrappers.map { |wrapper| wrapper.reference.capture }
    capture = wrap(capture, wrappers)
    prefix = repeat(wrap(Compiler.copy(skipped), wrappers), capture_first ? '*?' : '*')
    suffix = repeat(wrap(Compiler.copy(skipped), wrappers), lazy ? '*?' : '*')
    if capture_first != lazy
      cycle = Expression.new(:group, [prefix, capture])
      parts = [repeat(cycle, lazy ? '+?' : '+'), suffix]
    else
      cycle = Expression.new(:group, [capture, suffix])
      parts = [prefix, repeat(cycle, lazy ? '+?' : '+')]
    end
    return Expression.new(:group, parts) if required

    present = Expression.new(:branch, parts)
    absent_body = Expression.new(:group, [wrap(Compiler.copy(skipped), wrappers)])
    absent = Expression.new(:branch, [Expression.new(:native_repeat, [absent_body], quantity: quantity)])
    branches = quantity.mode == :lazy ? [absent, present] : [present, absent]
    Expression.new(:group, [Expression.new(:choice, branches)])
  end

  def repeat(expression, text)
    quantity = Compiler::Quantity.from_text(text)
    Expression.new(:native_repeat, [Expression.new(:group, [expression])], quantity: quantity)
  end

  def wrap(expression, wrappers)
    wrappers.reverse_each.reduce(expression) do |body, wrapper|
      occurrence = Compiler::Occurrence.new(wrapper.reference.capture)
      wrapper.with(children: [body], reference: occurrence)
    end
  end
end
