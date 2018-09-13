# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::TypeConverter do
  it 'preserves the digit type "\d"' do
    given_the_ruby_regexp(/\d/)
    expect_js_regex_to_be(/\d/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '+1', with_results: %w[1])
  end

  it 'preserves the non-digit type "\D"' do
    given_the_ruby_regexp(/\D/)
    expect_js_regex_to_be(/\D/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '+1', with_results: %w[+])
  end

  it 'preserves the whitespace type "\s"' do
    given_the_ruby_regexp(/\s/)
    expect_js_regex_to_be(/\s/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: ' b ', with_results: [' ', ' '])
  end

  it 'preserves the non-whitespace type "\S"' do
    given_the_ruby_regexp(/\S/)
    expect_js_regex_to_be(/\S/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: ' b ', with_results: %w[b])
  end

  it 'preserves the word type "\w"' do
    given_the_ruby_regexp(/\w/)
    expect_js_regex_to_be(/\w/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: ' b ', with_results: %w[b])
  end

  it 'preserves the non-word type "\W"' do
    given_the_ruby_regexp(/\W/)
    expect_js_regex_to_be(/\W/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: ' b ', with_results: [' ', ' '])
  end

  it 'translates the hex type "\h"' do
    given_the_ruby_regexp(/\h+/)
    expect_js_regex_to_be(/[0-9A-Fa-f]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'FF__FF', with_results: %w[FF FF])
  end

  it 'translates the nonhex type "\H"' do
    given_the_ruby_regexp(/\H+/)
    expect_js_regex_to_be(/[^0-9A-Fa-f]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'FFxy66z', with_results: %w[xy z])
  end

  it 'translates the generic linebreak type "\R"' do
    given_the_ruby_regexp(/\R/)
    expect_js_regex_to_be(/(?:\r\n|\r|\n)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "_\n_\r\n_", with_results: %W[\n \r\n])
  end

  it 'drops the extended grapheme type "\X" with warning' do
    given_the_ruby_regexp(/a\Xb/)
    expect_js_regex_to_be(/ab/)
    expect_warning("Dropped unsupported xgrapheme type '\\X' at index 1")
  end

  it 'drops unknown types with warning' do
    expect_to_drop_token_with_warning(:type, :an_unknown_type)
  end
end
