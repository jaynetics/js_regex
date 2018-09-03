# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::PropertyConverter do
  it 'translates the \p{...} property style' do
    given_the_ruby_regexp(/\p{ascii}/)
    expect_js_regex_to_be(/[\x00-\x7F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'añB', with_results: %w[a B])
  end

  it 'translates the negated \p{^...} property style' do
    given_the_ruby_regexp(/\p{^ascii}/)
    expect_js_regex_to_be(/[^\x00-\x7F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'añB', with_results: %w[ñ])
  end

  it 'translates the double-negated \P{^...} property style' do
    given_the_ruby_regexp(/\P{^ascii}/)
    expect_js_regex_to_be(/[\x00-\x7F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'añB', with_results: %w[a B])
  end

  it 'drops astral plane properties negated with \p{^ with warning' do
    given_the_ruby_regexp(/\p{^Deseret}/)
    expect_js_regex_to_be(//)
    expect_warning('astral plane')
  end

  it 'drops astral plane properties negated with \P with warning' do
    given_the_ruby_regexp(/\P{Deseret}/)
    expect_js_regex_to_be(//)
    expect_warning('astral plane')
  end

  it 'translates posix types' do
    given_the_ruby_regexp(/\p{xdigit}+/)
    expect_js_regex_to_be(/[0-9A-Fa-f]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '3GF', with_results: %w[3 F])
  end

  it 'translates unicode categories' do
    given_the_ruby_regexp(/\p{Control}/)
    expect(js_regex_source).to start_with('[\x00-\x1F\x7F-')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "\1 \2", with_results: %W[\1 \2])
  end

  it 'translates unicode derived core properties aka simple properties' do
    given_the_ruby_regexp(/\p{Dash}/)
    expect(js_regex_source).to start_with('[\x2D\u058A')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '-/-', with_results: %w[- -])
  end

  it 'translates unicode properties' do
    given_the_ruby_regexp(/\p{Currency_Symbol}/)
    expect(js_regex_source).to start_with('[$\xA2')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'A$ü€', with_results: %w[$ €])
  end

  it 'translates unicode scripts' do
    given_the_ruby_regexp(/\p{Cherokee}/)
    expect(js_regex_source).to start_with('[\u13A0-\u13F')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'AᏑBᏠC', with_results: %w[Ꮡ Ꮰ])
  end

  it 'translates abbreviated unicode refrences' do
    given_the_ruby_regexp(/\p{sc}/) # == currency_symbol
    expect(js_regex_source).to start_with('[$\xA2-')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'A$ü€', with_results: %w[$ €])
  end

  it 'translates unicode blocks' do
    given_the_ruby_regexp(Regexp.new('\p{InBasicLatin}'))
    expect_js_regex_to_be(Regexp.new('[\x00-\x7F]'))
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'añB', with_results: %w[a B])
  end

  it 'drops too large astral plane properties with warning' do
    # this should concern little more than the few astral plane scripts
    # supported by Ruby, but it is also a good precaution if spacy new
    # properties are added in the future.
    given_the_ruby_regexp(/\p{In_Supplementary_Private_Use_Area_A}/)
    expect_js_regex_to_be(//)
    expect_warning('astral plane')
  end
end
