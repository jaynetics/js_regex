module LangRegex
  # This is mixed into errors, e.g. those thrown by the parser,
  # allowing to `rescue LangRegex::Error`.
  module Error; end
end
