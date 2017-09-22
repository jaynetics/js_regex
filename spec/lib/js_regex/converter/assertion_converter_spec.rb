# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::AssertionConverter do
  it 'preserves positive lookaheads' do
    given_the_ruby_regexp(/a(?=b)/i)
    expect_js_regex_to_be(/a(?=b)/i)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aAb', with_results: %w[A])
  end

  it 'preserves negative lookaheads' do
    given_the_ruby_regexp(/a(?!b)/i)
    expect_js_regex_to_be(/a(?!b)/i)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aAb', with_results: %w[a])
  end

  it 'makes positive lookbehinds non-lookbehind with warning' do
    given_the_ruby_regexp(/(?<=A)b/)
    expect_js_regex_to_be(/(?:A)b/)
    expect_warning
  end

  it 'drops negative lookbehinds with warning' do
    given_the_ruby_regexp(/(?<!A)b/)
    expect_js_regex_to_be(/b/)
    expect_warning('negative lookbehind assertion')
  end

  it 'does not count towards captured groups' do
    expect_any_instance_of(JsRegex::Converter::Context)
      .not_to receive(:captured_group_count=)
      .with(1)
    JsRegex.new(/a(?=b)/i)
  end
end
