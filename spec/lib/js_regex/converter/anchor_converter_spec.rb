# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::AnchorConverter do
  it 'translates the beginning-of-string anchor "\A"' do
    given_the_ruby_regexp(/\A\w/)
    expect_js_regex_to_be(/^\w/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[a])
  end

  it 'translates the end-of-string anchor "\z"' do
    given_the_ruby_regexp(/\w\z/)
    expect_js_regex_to_be(/\w$/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[c])
  end

  it 'translates the end-of-string-with-optional-newline anchor "\Z"' do
    given_the_ruby_regexp(/\w\Z/)
    expect_js_regex_to_be(/\w(?=\n?$)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[c])
    expect_ruby_and_js_to_match(string: "abc\n", with_results: %w[c])
  end

  it 'preserves the beginning-of-line anchor "^"' do
    given_the_ruby_regexp(/^\w/)
    expect_js_regex_to_be(/^\w/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[a])
  end

  it 'preserves the end-of-line anchor "$"' do
    given_the_ruby_regexp(/\w$/)
    expect_js_regex_to_be(/\w$/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[c])
  end

  it 'preserves the word-boundary "\b" with a warning' do
    given_the_ruby_regexp(/\w\b/)
    expect_js_regex_to_be(/\w\b/)
    expect_warning("The boundary '\\b' at index 2 is not unicode-aware in "\
                   'JavaScript, so it might act differently than in Ruby.')
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[c])
  end

  it 'preserves the non-word-boundary "\B" with a warning' do
    given_the_ruby_regexp(/\w\B/)
    expect_js_regex_to_be(/\w\B/)
    expect_warning("The boundary '\\B' at index 2 is not unicode-aware in "\
                   'JavaScript, so it might act differently than in Ruby.')
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[a b])
  end

  it 'drops unknown anchors with warning' do
    expect_to_drop_token_with_warning(:anchor, :an_unknown_anchor)
  end
end
