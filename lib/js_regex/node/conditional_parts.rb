class JsRegex::Node
  def conditional_branches
    case type
    when :capture_conditional then children[1..-1]
    when :conditional         then children[1...-1]
    else raise TypeError, "cannot get conditional branches for #{type}"
    end
  end

  def condition_references
    case type
    when :capture_conditional then children.first.children.map(&:reference)
    when :conditional         then [reference]
    else raise TypeError, "cannot get condition references for #{type}"
    end
  end
end
