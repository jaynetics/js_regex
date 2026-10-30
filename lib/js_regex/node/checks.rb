class JsRegex::Node
  def dropped?
    # keep everything else, including empty or depleted capturing groups
    # so as not to not mess with reference numbers (e.g. backrefs)
    type.equal?(:dropped)
  end

  def branch?
    type == :branch
  end

  def alternation?
    children.any? && children.all? do |child|
      child.is_a?(JsRegex::Node) && child.branch?
    end
  end

  def repeated?
    !!quantifier&.repeated?
  end

  def optional?
    !!quantifier&.optional?
  end

  def zero_or_one?
    !!quantifier&.zero_or_one?
  end

  def zero_quantified?
    !!quantifier&.zero?
  end

  def max_one?
    !!quantifier&.max_one?
  end

  def negative_assertion?
    head = children.first
    head == '(?!' || head == '(?<!'
  end

  def positive_assertion?
    head = children.first
    head.is_a?(String) && (head.start_with?('(?=') || head == '(?<=')
  end

  def atomic?
    # Atomic groups are emitted as a lookahead followed by a backreference.
    children.first == '(?:(?='
  end

  def marked_nonempty?
    @marked_nonempty
  end

  # The body can match empty at any position, without relying on assertions
  # or backreferences. Neither flag being set means the body is uncertain.
  def nullable?
    @nullable
  end

  def conditional?
    type == :conditional || type == :capture_conditional
  end

  def internal_reference?
    REFERENCE_TYPES_MAP.key?(type)
  end
end
