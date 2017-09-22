# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::MetaConverter do
  it 'preserves the dot meta char a.k.a. universal matcher "."' do
    given_the_ruby_regexp(/./)
    expect_js_regex_to_be(/./)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: ' b%', with_results: [' ', 'b', '%'])
  end

  it 'ensures dots match newlines if the multiline option is set' do
    given_the_ruby_regexp(/a.+a/m)
    expect_js_regex_to_be(/a(?:.|\n)+a/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abba', with_results: %w[abba])
    expect_ruby_and_js_to_match(string: "ab\nba", with_results: %W[ab\nba])
  end

  it 'does not make dots match newlines if other options are set' do
    given_the_ruby_regexp(/a.+a/i)
    expect_js_regex_to_be(/a.+a/i)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abba', with_results: ['abba'])
    expect_ruby_and_js_to_match(string: "ab\nba", with_results: [])
  end

  it 'does not make escaped dots match newlines in multiline mode' do
    given_the_ruby_regexp(/a\.+a/m)
    expect_js_regex_to_be(/a\.+a/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aba a.a', with_results: %w[a.a])
    expect_ruby_and_js_to_match(string: "a\na a.a", with_results: %w[a.a])
  end

  it 'preserves the alternation meta char "|"' do
    given_the_ruby_regexp(/a|b/)
    expect_js_regex_to_be(/a|b/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a b', with_results: %w[a b])
  end

  it 'drops unknown meta elements with warning' do
    expect_to_drop_token_with_warning(:meta, :an_unknown_meta)
  end
end
