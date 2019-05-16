# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::TypeConverter do
  it 'preserves all types supported by JS' do
    expect(/\d\D\s\S\w\W/).to stay_the_same
  end

  it 'translates the hex type "\h"' do
    expect(/\h+/).to\
    become(/[0-9A-Fa-f]+/).and(keep_matching('FF__FF', with_results: %w[FF FF]))
  end

  it 'translates the nonhex type "\H"' do
    expect(/\H+/).to\
    become(/[^0-9A-Fa-f]+/).and keep_matching('FFxy66z', with_results: %w[xy z])
  end

  it 'translates the generic linebreak type "\R"' do
    expect(/\R/).to\
    become(/(?:\r\n|\r|\n)/)
      .and keep_matching("_\n_\r\n_", with_results: %W[\n \r\n])
  end

  it 'drops the extended grapheme type "\X" with warning' do
    expect(/a\Xb/).to\
    become(/ab/)
      .with_warning("Dropped unsupported xgrapheme type '\\X' at index 1")
  end

  it 'drops unknown types with warning' do
    expect([:type, :an_unknown_type]).to be_dropped_with_warning
  end
end
