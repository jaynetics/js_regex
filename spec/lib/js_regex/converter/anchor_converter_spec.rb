# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::AnchorConverter do
  it 'translates the beginning-of-string anchor "\A"' do
    given_the_ruby_regexp(/\A\w/)
    expect_js_regex_to_be(/^\w/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w(a))
  end

  it 'translates the end-of-string anchor "\z"' do
    given_the_ruby_regexp(/\w\z/)
    expect_js_regex_to_be(/\w$/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
  end

  it 'translates the end-of-string-with-optional-newline anchor "\Z"' do
    given_the_ruby_regexp(/\w\Z/)
    expect_js_regex_to_be(/\w(?=\n?$)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
    expect_ruby_and_js_to_match(string: "abc\n", with_results: %w(c))
  end

  it 'preserves the beginning-of-line anchor "^"' do
    given_the_ruby_regexp(/^\w/)
    expect_js_regex_to_be(/^\w/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w(a))
  end

  it 'preserves the end-of-line anchor "$"' do
    given_the_ruby_regexp(/\w$/)
    expect_js_regex_to_be(/\w$/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
  end

  it 'preserves the word-boundary "\b"' do
    given_the_ruby_regexp(/\w\b/)
    expect_js_regex_to_be(/\w\b/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
  end

  it 'preserves the non-word-boundary "\B"' do
    given_the_ruby_regexp(/\w\B/)
    expect_js_regex_to_be(/\w\B/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w(a b))
  end
end
