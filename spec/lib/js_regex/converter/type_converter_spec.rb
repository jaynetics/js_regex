# encoding: utf-8
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
    expect_js_regex_to_be(/[A-Fa-f0-9]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'FF__FF', with_results: %w[FF FF])
  end

  it 'translates the nonhex type "\H"' do
    given_the_ruby_regexp(/\H+/)
    expect_js_regex_to_be(/[^A-Fa-f0-9]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'FFxy66z', with_results: %w[xy z])
  end

  it 'drops unknown types with warning' do
    expect_to_drop_token_with_warning(:type, :an_unknown_type)
  end
end
