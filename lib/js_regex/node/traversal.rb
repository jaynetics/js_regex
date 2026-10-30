class JsRegex::Node
  # Traverse the node tree, depth first.
  # If `skip_self: true` is given, yield only the children and their descendants.
  # If `trace: true` is given, yield the node and its path on both entry and exit.
  def walk(skip_self: false, trace: false, path: [], &block)
    return enum_for(__method__, skip_self: skip_self, trace: trace, path: path) unless block

    if trace
      path << self
      yield(self, :enter, path) if !skip_self
    else
      yield(self) if !skip_self
    end

    children.each do |child|
      child.walk(trace: trace, path: path, &block) unless child.instance_of?(String)
    end

    if trace
      yield(self, :exit, path) if !skip_self
      path.pop
    end
  end
end
