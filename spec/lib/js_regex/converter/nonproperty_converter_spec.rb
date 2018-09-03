# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::NonpropertyConverter do
  it 'translates negated properties that are negated with ^' do
    given_the_ruby_regexp(/\p{^ascii}/)
    expect_js_regex_to_be(/[^\x00-\x7F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aaäa', with_results: %w[ä])
  end

  it 'translates negated properties that are negated with \P' do
    given_the_ruby_regexp(/\P{ascii}/)
    expect_js_regex_to_be(/[^\x00-\x7F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aaäa', with_results: %w[ä])
  end
end
