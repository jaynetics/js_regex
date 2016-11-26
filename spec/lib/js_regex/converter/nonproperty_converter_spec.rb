# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::NonpropertyConverter do
  it 'translates negated properties that are negated with ^' do
    given_the_ruby_regexp(/\p{^Cherokee}\p{^ascii}/)
    expect_js_regex_to_be(/[^\u13A0-\u13F4][^\x00-\x7F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aaäa', with_results: %w(aä))
  end

  it 'translates negated properties that are negated with \P' do
    given_the_ruby_regexp(/\P{Cherokee}\P{ascii}/)
    expect_js_regex_to_be(/[^\u13A0-\u13F4][^\x00-\x7F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aaäa', with_results: %w(aä))
  end

  it 'helps extracting negative \p-style properties from sets' do
    # c.f. set_converter.rb
    given_the_ruby_regexp(/[x-z\p{^ascii}]+/)
    expect_js_regex_to_be(/(?:[x-z]|[^\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'xañbäõ_ß', with_results: %w(x ñ äõ ß))
  end
end
