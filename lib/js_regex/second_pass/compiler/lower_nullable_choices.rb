# frozen_string_literal: true

require_relative 'analysis'
require_relative 'continuation'

class JsRegex::SecondPass::Compiler::LowerNullableChoices
  Compiler = JsRegex::SecondPass::Compiler
  Expression = Compiler::Expression

  def self.call(expression, analysis: nil)
    analysis ||= Compiler::Analysis.new(expression)
    unless analysis.unbounded_capture_loops
      root = analysis[expression]
      ambiguous = root.definitions.any? do |reference|
        !analysis.captures.fetch(reference).nonempty && root.references.key?(reference) &&
          !root.must_capture.include?(reference)
      end
      return expression unless ambiguous
    end
    new(expression, analysis).rewrite(expression)
  end

  def initialize(expression, analysis = nil)
    @analysis = analysis || Compiler::Analysis.new(expression)
    @references = @analysis[expression].references
    @summaries = {}
  end

  # Keep the continuation after the original choice, including its prefix's
  # backtracking. Only passive boundaries may absorb an outside continuation;
  # moving it into a capture, assertion, or iteration would change semantics.
  def rewrite(expression)
    return expression if expression.instance_of?(String) || @analysis[expression].definitions.empty?
    return expression unless [:sequence, :branch, :group, :capture, :choice, :lookahead, :negative_lookahead, :atomic].include?(expression.kind)

    unless [:choice, :atomic].include?(expression.kind)
      expression.children.each.with_index do |child, index|
        next unless ambiguous?(child) || needs_continuation?(child)

        following = expression.children.drop(index + 1)
        next if following.empty? || !@analysis.closed?([child, *following])

        replacement = distribute(child, following)
        next unless replacement

        prefix = expression.children.take(index).map { |part| rewrite(part) }
        return expression.with(children: [*prefix, replacement])
      end
    end
    children = expression.children.map { |child| rewrite(child) }
    children == expression.children ? expression : expression.with(children: children)
  end

  private

  def facts(expression)
    @analysis[expression]
  rescue KeyError
    @summaries[expression] ||= Compiler::Analysis.new(expression)[expression]
  end

  def ambiguous?(expression)
    return false if expression.instance_of?(String)

    summary = facts(expression)
    summary.definitions.any? do |reference|
      capture = @analysis.captures.fetch(reference)
      !capture.nonempty && @references.fetch(reference, 0) > 0 &&
        summary.may_capture.include?(reference) && !summary.must_capture.include?(reference)
    end
  end

  # Expanded required prefixes leave an unbounded tail inside passive choices.
  # Its stopping probes need the outside continuation, even when participation
  # is already certain. Only passive boundaries may carry that continuation in.
  def needs_continuation?(expression)
    return false if expression.instance_of?(String) || facts(expression).definitions.empty?
    if expression.kind == :repeat
      return expression.quantity.max < 0 && facts(expression.children.first).empty != :never
    end
    [:sequence, :group, :branch, :choice].include?(expression.kind) &&
      expression.children.any? { |child| needs_continuation?(child) }
  end

  def distribute(expression, following)
    case expression.kind
    when :group, :sequence, :branch
      return if expression.reference
      self.class.call(expression.with(children: [*expression.children, *following]))
    when :repeat
      quantity = expression.quantity
      return unless quantity.min.zero? && quantity.max == 1 && quantity.mode != :possessive

      body = expression.children.first
      variants = [body, Compiler::Specialize.disable(body)]
      variants.reverse! if quantity.mode == :lazy
      tail = Expression.new(:sequence, following)
      if body.kind == :capture && facts(body).definitions.length == 1 && @analysis.closed?(following)
        # The common scalar case can lower its closed tail once. Specializing
        # and copying that result is cheaper than analyzing each arm again.
        continuation = Compiler::Continuation.new(self.class.call(tail))
        return alternatives(variants.map do |variant|
          continuation.branch(variant, body.reference => variant.equal?(body))
        end)
      end
      alternatives(variants.map { |variant| branch(variant, following) })
    when :choice
      choices = expression.children.reject { |child| child.kind == :omitted_branch }
      alternatives(choices.each_index.map do |index|
        branch(select_branch(choices, index), following, states: selected_states(choices, index))
      end)
    when :conditional, :capture_conditional
      offset = expression.kind == :capture_conditional ? 1 : 0
      choices = expression.children.drop(offset)
      choices = [*choices, Expression.new(:sequence)] if choices.length == 1
      variants = choices.each_index.map do |index|
        branch(select_branch(choices, index), following, states: selected_states(choices, index))
      end
      expression.with(children: [*expression.children.take(offset), *variants])
    when :capture
      variants = lifted_choices(expression)
      alternatives(variants.map { |variant| branch(variant, following) }) if variants
    end
  end

  # A sole nested choice can move outside a capture if each arm retains its
  # capture wrapper. Do not lift across a preceding expression: its backtracking
  # must still try all choices before retrying that prefix.
  def lifted_choices(expression)
    return if expression.instance_of?(String)

    case expression.kind
    when :repeat
      quantity = expression.quantity
      return unless quantity.min.zero? && quantity.max == 1 && quantity.mode != :possessive
      body = expression.children.first
      variants = [body, Compiler::Specialize.disable(body)]
      quantity.mode == :lazy ? variants.reverse : variants
    when :choice
      choices = expression.children.reject { |child| child.kind == :omitted_branch }
      choices.each_index.map { |index| select_branch(choices, index) }
    when :sequence, :branch, :group, :capture
      return unless expression.children.length == 1
      variants = lifted_choices(expression.children.first)
      variants&.map { |variant| expression.with(children: [variant]) }
    end
  end

  def select_branch(choices, selected)
    Expression.new(:sequence, choices.each_with_index.map do |choice, index|
      index == selected ? choice : Compiler::Specialize.disable(choice)
    end)
  end

  def selected_states(choices, selected)
    # Disabled arms retain capture definitions but cannot participate. Reuse
    # the original arm summaries instead of analyzing the assembled sequence.
    summary = facts(choices[selected])
    states = summary.must_capture.to_h { |reference| [reference, true] }
    choices.each do |choice|
      facts(choice).definitions.each do |reference|
        states[reference] = false unless summary.may_capture.include?(reference)
      end
    end
    states
  end

  def branch(prefix, following, states: nil)
    unless states
      summary = facts(prefix)
      states = summary.must_capture.to_h { |reference| [reference, true] }
      (summary.definitions - summary.may_capture).each { |reference| states[reference] = false }
    end
    # Lower nested choices before copying. All definitions in this region are
    # closed, so a local analysis can safely account for the specialized uses.
    continuation = Compiler::Continuation.new(Expression.new(:sequence, following))
    continuation.branch(prefix, states) { |combined| self.class.call(combined) }
  end

  def alternatives(branches)
    Expression.new(:group, [Expression.new(:choice, branches)])
  end
end
