# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::AssertionConverter do
  it 'preserves positive lookahead groups' do
    given_the_ruby_regexp(/a(?=b)/i)
    expect_js_regex_to_be(/a(?=b)/i)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aAb', with_results: ['A'])
  end

  it 'preserves negative lookahead groups' do
    given_the_ruby_regexp(/a(?!b)/i)
    expect_js_regex_to_be(/a(?!b)/i)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aAb', with_results: ['a'])
  end

  it 'makes positive lookbehind groups non-lookbehind with warning' do
    given_the_ruby_regexp(/(?<=A)b/)
    expect_js_regex_to_be(/(?:A)b/)
    expect_warning
  end

  it 'drops negative lookbehind groups with warning' do
    given_the_ruby_regexp(/(?<!A)b/)
    expect_js_regex_to_be(/b/)
    expect_warning
  end
end
