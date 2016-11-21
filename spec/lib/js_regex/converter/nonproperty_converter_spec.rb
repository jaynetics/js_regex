# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter::NonpropertyConverter do
  it 'translates the negated [[:^...:]] property style' do
    given_the_ruby_regexp(/[[:^ascii:]]/)
    expect_js_regex_to_be(/[^\x00-\x7F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'añB', with_results: %w(ñ))
  end

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

  it 'translates negations of negative properties by making them positive' do
    given_the_ruby_regexp(/\p{graph}/)
    expect(@js_regex.source).to start_with('[^\s\x00')

    given_the_ruby_regexp(/\p{^graph}/)
    expect(@js_regex.source).to start_with('[\s\x00')
  end

  it 'drops unknown negated properties with warning' do
    # this should concern little more than the few astral plane scripts
    # supported by Ruby, but it is also a good precaution if spacy new
    # properties are added in the future.
    given_the_ruby_regexp(/\p{Deseret}/)
    expect_js_regex_to_be(//)
    expect_warning
  end
end
