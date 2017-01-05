# frozen_string_literal: true

class JsRegex
  PERFORM_FULL_BUILD =
    Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.4.0')
end
