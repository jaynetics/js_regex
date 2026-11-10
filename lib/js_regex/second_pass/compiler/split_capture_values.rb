# frozen_string_literal: true

require_relative 'analysis'

# Keep backtracking prefixes in place when a nullable choice cannot cross its
# enclosing capture. Consecutive captured segments reconstruct the same value;
# their boundaries can then be lowered independently without moving the prefix.
class JsRegex::SecondPass::Compiler::SplitCaptureValues
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, analysis: nil)
    analysis ||= Compiler::Analysis.new(expression)
    return expression unless analysis.captures.any? { |_, capture| analysis[capture].definitions.length > 1 }
    new(expression, analysis).call(expression)
  end

  def initialize(expression, analysis)
    @analysis = analysis || Compiler::Analysis.new(expression)
    @references = @analysis[expression].references
    @segments = {}
    @parts = {}
  end

  def call(expression)
    result = split(expression)
    @segments.empty? ? result : rewrite_references(result)
  end

  private

  def split(expression, bounded_empty = false)
    return expression if expression.instance_of?(String)
    if expression.kind == :repeat && expression.quantity.max > 1
      facts = @analysis[expression.children.first]
      bounded_empty ||= facts.empty != :never && facts.may_capture.any? { |ref| @references.fetch(ref, 0) > 0 }
    end
    children = expression.children.map { |child| split(child, bounded_empty) }
    result = children == expression.children ? expression : expression.with(children: children)
    return result unless expression.kind == :capture && candidate?(expression, bounded_empty)
    body = Compiler.unwrap(Expression.new(:sequence, children))
    return result unless [:sequence, :group, :branch].include?(body.kind) && body.children.length > 1

    references = []
    segments = body.children.map do |part|
      unwrapped = part.instance_of?(String) ? part : Compiler.unwrap(part)
      existing = @parts[unwrapped]
      existing ||= [unwrapped.reference] if !unwrapped.instance_of?(String) && unwrapped.kind == :capture
      if existing
        references.concat(existing)
        next part
      end
      # The rewritten parts need fresh summaries only when nested captures split.
      facts = children == expression.children ? @analysis[part] : Compiler::Analysis.new(part)[part]
      reference = Compiler::Occurrence.new
      references << reference
      Expression.new(:capture, [part], reference: reference,
                     nonempty: facts.empty == :never, nullable: facts.empty == :always)
    end
    @segments[expression.reference] = references
    result = Expression.new(:group, segments)
    @parts[result] = references
    result
  end

  def candidate?(capture, bounded_empty)
    facts = @analysis[capture]
    return false if facts.references.key?(capture.reference)
    (facts.may_capture - facts.must_capture).any? do |reference|
      # Internal reads can be lowered with their continuation inside this
      # capture. Segmentation is needed only for escaping reads or bounded-loop
      # instrumentation; otherwise it can hide a loop behind a new boundary.
      escaping = @references.fetch(reference, 0) > facts.references.fetch(reference, 0)
      !@analysis.captures.fetch(reference).nonempty && (bounded_empty || escaping)
    end
  end

  def rewrite_references(expression)
    return expression if expression.instance_of?(String)
    if [:history, :multiplex].include?(expression.kind) &&
       @analysis[expression].references.any? { |reference, _| @segments.key?(reference) }
      return rewrite_references(select_value(expression))
    end
    children = expression.children.map { |child| rewrite_references(child) }
    references = @segments[expression.reference]
    if references && [:backreference, :value].include?(expression.kind)
      values = references.map { |reference| Expression.new(expression.kind, [], reference: reference) }
      return Expression.new(:group, [*values, *children])
    end
    # Outside the capture, all segments participate together. Self-reads were
    # excluded above because the first segment closes before the original group.
    reference = references ? references.first : expression.reference
    return expression if children == expression.children && reference.equal?(expression.reference)
    expression.with(children: children, reference: reference)
  end

  # Select the complete value before decomposing it. Histories commit to the
  # latest participating capture; duplicate names commit to the first matching
  # value. Selecting individual segments could combine different candidates.
  def select_value(expression)
    expression.children.reverse_each.reduce(nil) do |fallback, candidate|
      next candidate unless fallback
      if expression.kind == :history
        Expression.new(:conditional, [candidate, fallback], reference: candidate.reference)
      else
        rejected = Expression.new(:negative_lookahead, [candidate])
        Expression.new(:group, [Expression.new(:choice, [Expression.new(:branch, [candidate]),
                                                        Expression.new(:branch, [rejected, fallback])])])
      end
    end
  end
end
