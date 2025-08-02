# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::TypeConverter do
  it 'preserves all types supported by JS in regular mode' do
    expect(/\d\D\s\S\w\W/).to stay_the_same
  end

  it 'substitutes \d, \w, \D and \W with an equivalent set in unicode mode' do
    expect(/(?u)\d/).to keep_matching('8', "９") # wide number nine
    expect(/(?u)\D/).to keep_not_matching('8', "９")
    expect(/(?u:\w)/).to keep_matching('a', "ใ") # thai letter sara ai maimuan
    expect(/(?u:\W)/).to keep_not_matching('a', "ใ")
  end

  it 'does not substitute \s in unicode mode, it already matches all spaces' do
    expect(/(?u)\s/).to\
    become(/\s/).and keep_matching(' ', " ") # ogham space mark
    expect(/(?u)\S/).to\
    become(/\S/).and keep_not_matching(' ', " ")
  end

  it 'substitutes \s in ascii mode to match less spaces' do
    # To be fair, \s and \S match less in Ruby even with the default encoding,
    # but only compared to modern browsers, and we don't want tons of diff...
    expect(/(?a)\s/)
      .to keep_matching(' ').and keep_not_matching(" ") # ogham space mark
    expect(/(?a)\S/)
      .to keep_matching(" ").and keep_not_matching(' ')
  end

  it 'substitutes the hex type "\h" with an equivalent set', targets: [ES2009, ES2015] do
    expect(/\h+/).to\
    become(/[0-9A-Fa-f]+/).and keep_matching('f').and keep_not_matching('x')
  end

  it 'substitutes the hex type "\h" with an equivalent set in i-mode', targets: [ES2009, ES2015] do
    expect(/\h+/i).to\
    become(/[0-9A-F]+/i).and keep_matching('f').and keep_not_matching('x')
  end

  it 'substitutes the hex type "\h" with an equivalent property on ES2018+', targets: [ES2018] do
    expect(/\h+/).to\
    become(/\p{AHex}+/).and keep_matching('f').and keep_not_matching('x')
  end

  it 'substitutes the nonhex type "\H" with an equivalent set', targets: [ES2009, ES2015] do
    expect(/\H+/).to\
    become(/[^0-9A-Fa-f]+/).and keep_matching('x').and keep_not_matching('f', 'F')
  end

  it 'substitutes the nonhex type "\H" with an equivalent set in i-mode', targets: [ES2009, ES2015] do
    expect(/\H+/i).to\
    become(/[^0-9A-F]+/i).and keep_matching('x').and keep_not_matching('f', 'F')
  end

  it 'substitutes the nonhex type "\H" with an equivalent property on ES2018+', targets: [ES2018] do
    expect(/\H+/).to\
    become(/\P{AHex}+/).and keep_matching('x').and keep_not_matching('f', 'F')
  end

  it 'substitutes the generic linebreak type "\R", preserving atomicity' do
    expect(/\R/).to\
    become(/(?:(?=((?:\r\n|[\n\v\f\r\u0085\u2028\u2029])))\1)/)
      .and keep_matching("_\n_\r\n_", with_results: %W[\n \r\n])

    expect(/\R\n/).to keep_not_matching("\r\n")
  end

  it 'drops the extended grapheme type "\X" with warning', targets: [ES2009, ES2015] do
    expect(/a\Xb/).to\
    become(/ab/)
      .with_warning("Dropped unsupported xgrapheme type '\\X' at index 1")
  end

  it 'substitutes the extended grapheme type "\X"', targets: [ES2018] do
    expect(/\X/)
      .to keep_matching("aaßßギギn\u0303n\u0303\r\n\n\r😃😃👍🏿👍🏿🏳️‍🌈🏴󠁧󠁢󠁷󠁬󠁳󠁿👩🏻‍🏫", with_results: [
        "a", "a", "ß", "ß", "ギ", "ギ", "n\u0303", "n\u0303",
        "\r\n", "\n", "\r",
        "😃", "😃", "👍🏿", "👍🏿", '🏳️‍🌈', '🏴󠁧󠁢󠁷󠁬󠁳󠁿', '👩🏻‍🏫'
      ])
  end

  it 'drops unknown types with warning' do
    expect([:type, :an_unknown_type]).to be_dropped_with_warning
  end
end
