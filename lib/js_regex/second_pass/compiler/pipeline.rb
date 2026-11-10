# frozen_string_literal: true

Dir[File.join(__dir__, '*.rb')].sort.each { |file| require file }

class JsRegex::SecondPass::Compiler
  FEATURES = %i[
    backref
    capture_backref
    capture_check
    capture_conditional
    conditional
    keep_mark
    multiplex_backref
  ].to_h { |type| [type, true] }.freeze

  REWRITES = [
    SimplifyLoops,
    SplitCaptureValues,
    FlattenCharacterLoops,
    ExpandBoundedLoops,
    PreserveCaptureCycles,
    LowerCaptureStates,
    LowerNullableChoices,
    LowerNullableLoops,
    LowerLazyRuns,
  ].freeze

  UNBOUNDED_REWRITES_MAP = [
    FlattenCharacterLoops,
    PreserveCaptureCycles,
    LowerCaptureStates,
    LowerNullableLoops,
    LowerLazyRuns,
  ].to_h { |type| [type, true] }.freeze

  # Experimental, opt-in pipeline for converter trees. Unsupported constructs
  # raise before changing the caller's root; there is no legacy fallback.
  def self.call(tree)
    return tree unless needs_work?(tree)

    original = Importer.call(tree)
    analysis = Analysis.new(original)
    expression = LowerKeepMarks.call(RequireCaptures.call(original, analysis: analysis))
    analysis = nil unless expression.equal?(original)

    REWRITES.each do |rewrite|
      analysis ||= Analysis.new(expression)
      next if UNBOUNDED_REWRITES_MAP.key?(rewrite) && !analysis.unbounded_capture_loops
      next if rewrite == ExpandBoundedLoops && !analysis.bounded_capture_loops && !analysis.unbounded_capture_loops

      result = rewrite.call(expression, analysis: analysis)
      analysis = nil unless result.equal?(expression)
      expression = result
    end

    expression = ResolveReferences.call(expression, analysis: analysis)
    emitted = DelimitReferences.call(Emitter.call(expression, compact: true))
    tree.update(type: emitted.type, reference: emitted.reference,
                quantifier: emitted.quantifier, children: emitted.children)
  end

  def self.needs_work?(node)
    return false if node.instance_of?(String)
    return true if FEATURES.key?(node.type)

    quantity = node.quantifier
    if quantity&.max.to_i.nonzero?
      return true if node.children.any? { |child| nullable_part?(child) }
    end
    node.children.any? { |child| needs_work?(child) }
  end

  # A cheap, conservative screen before allocating the IR. Nullable nested
  # quantifiers and empty branches need inspection even without references;
  # ordinary literal runs and wholly consuming groups retain the fast path.
  def self.nullable_part?(node)
    return node.empty? if node.instance_of?(String)

    node.children.empty? || node.optional? || node.children.any? { |child| nullable_part?(child) }
  end
  private_class_method :needs_work?, :nullable_part?
end
