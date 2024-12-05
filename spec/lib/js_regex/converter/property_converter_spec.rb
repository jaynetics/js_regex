require 'spec_helper'

describe LangRegex::Converter::PropertyConverter do
  it 'substitutes the \p{...} property style', targets: [ES2009, ES2015] do
    expect(/\p{ascii}/).to\
    become(/[\x00-\x7F]/).and keep_matching('añB', with_results: %w[a B])
  end

  it 'keeps properties that behave the same on ES2018+', targets: [ES2018] do
    expect(/\p{ascii}/).to\
    become(/\p{ASCII}/).and keep_matching('añB', with_results: %w[a B])
  end

  it 'substitutes props that are unavailable or behave differently on ES2018+', targets: [ES2018] do
    expect(/\p{xdigit}/).to\
    become('[0-9A-Fa-f]').and keep_matching('añB', with_results: %w[a B])
  end

  it 'substitutes the negated \p{^...} property style', targets: [ES2009, ES2015] do
    expect(/\p{^ascii}/).to\
    become('(?:[\x80-\uD7FF\uE000-\uFFFF]|[\uD800-\uDBFF][\uDC00-\uDFFF])')
      .and keep_matching('añB😁', with_results: %w[ñ 😁])
  end

  it 'keeps supported negated properties on ES2018+', targets: [ES2018] do
    expect(/\p{^ascii}/).to\
    become(/\P{ASCII}/).and keep_matching('añB', with_results: %w[ñ])
  end

  it 'adds the required script prefix for script properties on ES2018+', targets: [ES2018] do
    expect(/\p{thai}/).to\
    become('\p{Script=Thai}').and keep_matching('aใB', with_results: %w[ใ])
  end

  it 'translates the double-negated \P{^...} property style', targets: [ES2009, ES2015] do
    expect(/\P{^ascii}/).to\
    become(/[\x00-\x7F]/).and keep_matching('añB', with_results: %w[a B])
  end

  it 'substitutes abbreviated properties', targets: [ES2009, ES2015] do
    expect(/\p{cc}/).to\
    become('[\x00-\x1F\x7F-\x9F]')
      .and keep_matching('A B', with_results: %w[ ])
  end

  it 'keeps supported abbreviated properties', targets: [ES2018] do
    expect(/\p{cc}/).to\
    become(/\p{Control}/)
      .and keep_matching('A B', with_results: %w[ ])
  end

  it 'uses case-insensitive substitutions if needed' do
    result = LangRegex::JsRegex.new(/1(?i:\p{lower})2/)
    expect(result.source).to include 'A-Z'
  end

  it 'does not use case-insensitive substitutions if everything is i anyway' do
    result = LangRegex::JsRegex.new(/1\p{lower}2/i)
    expect(result.source).not_to include 'A-Z'
    expect(result.warnings).to be_empty
  end

  it 'warns for nested case-sensitive properties' do
    expect(/(?-i:\p{upper})/i)
      .to generate_warning('nested case-sensitive property')
  end
end
