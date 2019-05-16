# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::PropertyConverter do
  it 'translates the \p{...} property style' do
    expect(/\p{ascii}/).to\
    become(/[\x00-\x7F]/).and keep_matching('añB', with_results: %w[a B])
  end

  it 'translates the negated \p{^...} property style' do
    expect(/\p{^ascii}/).to\
    become(/[^\x00-\x7F]/).and keep_matching('añB', with_results: %w[ñ])
  end

  it 'translates the double-negated \P{^...} property style' do
    expect(/\P{^ascii}/).to\
    become(/[\x00-\x7F]/).and keep_matching('añB', with_results: %w[a B])
  end

  it 'drops astral plane properties negated with \p{^ with warning' do
    expect(/\p{^Deseret}/).to\
    become(//).with_warning('astral plane negation by property')
  end

  it 'drops astral plane properties negated with \P with warning' do
    expect(/\P{Deseret}/).to\
    become(//).with_warning('astral plane negation by property')
  end

  it 'translates abbreviated properties' do
    expect(/\p{cc}/).to\
    become(double(source: '[\x00-\x1F\x7F-\x9F]'))
      .and keep_matching('A B', with_results: %w[ ])
  end

  it 'uses case-insensitive substitutions if needed' do
    result = JsRegex.new(/1(?i:\p{lower})2/)
    expect(result.source).to include 'A-Z'
  end

  it 'does not use case-insensitive substitutions if everything is i anyway' do
    result = JsRegex.new(/1\p{lower}2/i)
    expect(result.source).not_to include 'A-Z'
  end

  it 'cuts of large astral plane shares of properties with warning' do
    expect(JsRegex::Converter).to(receive(:in_surrogate_pair_limit?) do |&block|
      expect(block.call).to eq 1048576
    end).and_return(false)
    expect(/\p{Any}/).to\
    become(/[\x00-\uFFFF]/).with_warning('large astral plane match of property')
  end

  it 'drops too large astral plane properties with warning',
    if: (Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.4.1')) do
    # this should concern little more than the few astral plane scripts
    # supported by Ruby, but it is also a good precaution if spacy new
    # properties are added in the future.
    expect(JsRegex::Converter)
      .to receive(:in_surrogate_pair_limit?)
      .and_call_original
    expect(Regexp.new('\p{SignWriting}'))
      .to become(//)
      .with_warning('large astral plane match of property')
  end

  it 'allows large astral plane properties if the limit allows it',
    if: (Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.4.1')) do
    expect(JsRegex::Converter)
      .to receive(:in_surrogate_pair_limit?)
      .and_return(true)
    expect(Regexp.new('a\p{SignWriting}b')).to keep_matching('a𝠔b')
  end
end
