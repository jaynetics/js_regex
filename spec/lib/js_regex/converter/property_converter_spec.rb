require 'spec_helper'

describe JsRegex::Converter::PropertyConverter do
  it 'translates the \p{...} property style' do
    expect(/\p{ascii}/).to\
    become(/[\x00-\x7F]/).and keep_matching('añB', with_results: %w[a B])
  end

  it 'translates the negated \p{^...} property style' do
    expect(/\p{^ascii}/).to\
    become('(?:[\x80-\uD7FF\uE000-\uFFFF]|[\uD800-\uDBFF][\uDC00-\uDFFF])')
      .and keep_matching('añB😁', with_results: %w[ñ 😁])
  end

  it 'translates the double-negated \P{^...} property style' do
    expect(/\P{^ascii}/).to\
    become(/[\x00-\x7F]/).and keep_matching('añB', with_results: %w[a B])
  end

  it 'translates abbreviated properties' do
    expect(/\p{cc}/).to\
    become('[\x00-\x1F\x7F-\x9F]')
      .and keep_matching('A B', with_results: %w[ ])
  end

  it 'uses case-insensitive substitutions if needed' do
    result = JsRegex.new(/1(?i:\p{lower})2/)
    expect(result.source).to include 'A-Z'
  end

  it 'does not use case-insensitive substitutions if everything is i anyway' do
    result = JsRegex.new(/1\p{lower}2/i)
    expect(result.source).not_to include 'A-Z'
    expect(result.warnings).to be_empty
  end

  it 'warns for nested case-sensitive properties' do
    expect(/(?-i:\p{upper})/i)
      .to generate_warning('nested case-sensitive property')
  end
end
