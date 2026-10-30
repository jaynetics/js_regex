class JsRegex::Node
  # Creates a copy with the given attributes replaced, without mutating self.
  def with(**attrs)
    validate_attrs(**attrs)
    children = attrs.key?(:children) ? attrs.delete(:children) : self.children.map(&:clone)
    new_attrs = (ATTRIBUTES - [:children]).to_h do |attr|
      [attr, attrs.fetch(attr) { send(attr) }]
    end
    self.class.new(*children, **new_attrs)
  end

  # Mutates self with validations.
  def update(**attrs)
    validate_attrs(**attrs)
    ATTRIBUTES.each { |attr| send("#{attr}=", attrs.fetch(attr)) if attrs.key?(attr) }
    self
  end

  def transform(&block)
    children.map!(&block)
    self
  end

  # Preserve optionality: a failing node with ? can still be skipped.
  def make_unmatchable
    update(type: :plain, reference: nil, children: ['(?!)'])
  end

  # Keep numeric reference text in sync with its annotation. Captures and
  # unresolved conditions only store the number in their annotation.
  def renumber(number)
    self.reference = number
    case type
    when :backref, :capture_check      then update(children: ["\\#{number}"])
    when :captured_group, :conditional then nil
    else raise TypeError, "cannot renumber #{type} node"
    end
    self
  end

  def make_passive
    raise TypeError, "cannot make #{type} passive" unless type == :captured_group

    update(type: :plain, reference: nil, children: ['(?:', *children[1..-1]])
  end

  def quantify(min, max, reluctant: false)
    update(quantifier: Quantifier.new(min, max, reluctant: reluctant))
  end

  private

  def validate_attrs(**attrs)
    attrs.each_key { |k| ATTRIBUTES.include?(k) || raise(ArgumentError, "no attribute #{k}") }
  end
end
