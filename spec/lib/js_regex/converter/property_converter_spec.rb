# encoding: utf-8
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

  it 'translates negations of negative properties by making them positive' do
    given_the_ruby_regexp(/\p{graph}/)
    expect(@js_regex.source).to start_with('[^\s\x00')

    given_the_ruby_regexp(/\p{^graph}/)
    expect(@js_regex.source).to start_with('[\s\x00')
  end

  it 'drops unknown properties negated with \p{^ with warning' do
    # this should concern little more than the few astral plane scripts
    # supported by Ruby, but it is also a good precaution if spacy new
    # properties are added in the future.
    given_the_ruby_regexp(/\p{^Deseret}/)
    expect_js_regex_to_be(//)
    expect_warning
  end

  it 'drops unknown properties negated with \P with warning' do
    given_the_ruby_regexp(/\P{Deseret}/)
    expect_js_regex_to_be(//)
    expect_warning
  end

  it 'translates posix types' do
    given_the_ruby_regexp(/\p{xdigit}+/)
    expect_js_regex_to_be(/[A-Fa-f0-9]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '3GF', with_results: %w[3 F])
  end

  it 'translates unicode categories' do
    given_the_ruby_regexp(/\p{Control}/)
    expect_js_regex_to_be(/[\x00-\x1F\x7F-\u009F]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "\1 \2", with_results: ["\1", "\2"])
  end

  it 'translates unicode derived core properties aka simple properties' do
    given_the_ruby_regexp(/\p{Dash}/)
    expect(@js_regex.source).to start_with('[\u002D\u058A\u05BE')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '-/-', with_results: %w[- -])
  end

  it 'translates unicode properties' do
    given_the_ruby_regexp(/\p{Any}/)
    expect_js_regex_to_be(/[\x00-\uFFFF]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'Añ字', with_results: %w[A ñ 字])
  end

  it 'translates unicode scripts' do
    given_the_ruby_regexp(/\p{Cherokee}/)
    expect_js_regex_to_be(/[\u13A0-\u13F4]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'AᏑBᏠC', with_results: %w[Ꮡ Ꮰ])
  end

  it 'translates abbreviated unicode refrences' do
    given_the_ruby_regexp(/\p{sc}/) # == currency_symbol
    expect(@js_regex.source).to start_with('[\x24\u00A2-')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a$c', with_results: %w[$])
  end

  it 'translates unicode ages',
     if: ruby_version_at_least?('1.9.3') do
    given_the_ruby_regexp(Regexp.new('\p{Age=2.0}'))
    expect(@js_regex.source).to end_with('\uD7A3]')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'A؜힣', with_results: %w[A 힣])
  end

  it 'translates unicode blocks',
     if: ruby_version_at_least?('2.0') do
    given_the_ruby_regexp(Regexp.new('\p{InBasicLatin}'))
    expect_js_regex_to_be(Regexp.new('[\x00-\u007F]'))
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'añB', with_results: %w[a B])
  end

  it 'drops unknown properties with warning' do
    # this should concern little more than the few astral plane scripts
    # supported by Ruby, but it is also a good precaution if spacy new
    # properties are added in the future.
    given_the_ruby_regexp(/\p{Deseret}/)
    expect_js_regex_to_be(//)
    expect_warning
  end

  it 'can handle properties irrespective of case' do
    expect(described_class.property_replacement('AsCiI')).not_to be_nil
  end
end
