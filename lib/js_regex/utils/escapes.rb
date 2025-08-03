# frozen_string_literal: true

class JsRegex
  module Utils
    module Escapes
      ESCAPES_SHARED_BY_RUBY_AND_JS = %i[
        alternation
        backslash
        backspace
        bol
        carriage
        codepoint
        dot
        eol
        form_feed
        group_close
        group_open
        hex
        interval_close
        interval_open
        newline
        one_or_more
        set_close
        set_open
        tab
        vertical_tab
        zero_or_more
        zero_or_one
      ].freeze
    end
  end
end
