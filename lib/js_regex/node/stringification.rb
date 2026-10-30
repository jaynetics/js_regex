class JsRegex::Node
  def to_s
    case type
    when :dropped
      ''
    when :backref, :branch, :capture_check, :captured_group, :plain
      children.join << quantifier.to_s
    else
      raise TypeError.new(
        "#{type} must be substituted before stringification"
      ).extend(JsRegex::Error)
    end
  end
end
