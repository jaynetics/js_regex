class JsRegex
  # This is mixed into errors, e.g. those thrown by the parser,
  # allowing to `rescue JsRegex::Error`.
  module Error; end
end
