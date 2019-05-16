# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::SetConverter do
  it 'preserves hex escape members' do
    expect(/[\x41]/).to stay_the_same.and keep_matching('ABC', with_results: %w[A])
  end

  it 'preserves hex escape ranges' do
    expect(/[\x41-\x43]+/).to stay_the_same.and keep_matching('ABC', with_results: %w[ABC])
  end

  it 'converts ranges with delimiters that are not js-compatible' do
    expect(/[\a-z]/).to become(/[\x07-z]/).and keep_matching("\a")
  end

  context 'when sets are nested' do
    it 'flattens simple nested sets' do
      expect(/[a-z[0-9]]+/).to\
      become(/[0-9a-z]+/).and keep_matching('ab_12', with_results: %w[ab 12])
    end

    it 'handles nested sets in negative sets' do
      expect(/[^a-c[0-9]]+/).to\
      become(/[\x00-\/:-`d-\uD7FF\uE000-\uFFFF]+/)
        .with_warning('large astral plane match of set')
        .and keep_matching('abc123xyz', with_results: %w[xyz])
    end

    it 'isnt distracted by escaped brackets' do
      expect(/[a-z\][0-9\[]ä-ü]+/)
        .to keep_matching(']a_1[', with_results: %w(]a 1[))
    end

    it 'handles negative sets nested in negative sets' do
      expect(/[^a[^b]]+/).to\
      become(/[b]+/).and keep_matching('abc', with_results: %w[b])
    end

    it 'can flatten multiple nested sets' do
      expect(/[[a-c][x-z][0-2]]+/).to\
      become(/[0-2a-cx-z]+/)
        .and keep_matching('bmx_123', with_results: %w[b x 12])
    end

    it 'can flatten multiple sets nested in negative sets' do
      expect(/[^a-c[x-z][0-2]]+/).to\
      become(/[\x00-\/3-`d-w{-\uD7FF\uE000-\uFFFF]+/)
        .with_warning('large astral plane match of set')
        .and keep_matching('bmx_123', with_results: %w[m _ 3])
    end

    it 'can flatten deeply nested sets' do
      expect(/[a-c[x-z[0-2]]]+/).to\
      become(/[0-2a-cx-z]+/)
        .and keep_matching('bmx_123', with_results: %w[b x 12])
    end

    it 'can flatten deeply nested sets in negative sets' do
      expect(/[^a-c[x-z[0-2]]]+/).to\
      become(/[\x00-\/3-`d-w{-\uD7FF\uE000-\uFFFF]+/)
        .with_warning('large astral plane match of set')
        .and keep_matching('bmx_123', with_results: %w[m _ 3])
    end

    it 'can handle deeply nested negative sets' do
      expect(/[a-c[x-z[^0-2]]]+/).to\
      become(/[\x00-\/3-\uD7FF\uE000-\uFFFF]+/)
        .with_warning('large astral plane match of set')
        .and keep_matching('bmx_123', with_results: %w[bmx_ 3])
    end

    it 'can handle deeply nested negative sets in negated sets' do
      expect(/[^a-c[x-z[^0-2]]]+/).to\
      become(/[0-2]+/).and keep_matching('bmx_123', with_results: %w[12])
    end

    it 'can handle deeply nested negative sets with properties' do
      expect(/[^a-c[x-z[^\p{ascii}]]]+/).to\
      become(/[\x00-`d-w{-\x7F]+/)
        .and keep_matching('bmx_123', with_results: %w[m _123])
    end

    it 'can handle non-astral literals in negative sets' do
      expect(/[^\uFFFF]/).to stay_the_same.and keep_matching("a\uFFFFb", with_results: %w[a b])
    end

    it 'warns for astral literals in negative sets' do
      expect(/[^\u{10000}]/).to\
      become(/[\x00-\uD7FF\uE000-\uFFFF]/)
        .with_warning('large astral plane match of set')
    end
  end

  it 'expands the hex type in positive sets' do
    expect(/[w-y\h]+/).to\
    become(/[0-9A-Fa-fw-y]+/).and keep_matching('zxa3n', with_results: %w[xa3])
  end

  it 'handles the hex type in negative sets' do
    expect(/[^x-y\h]+/)
      .to generate_warning('large astral plane match of set')
      .and keep_matching('zxa3n', with_results: %w[z n])
  end

  it 'expands the non-hex type in negative sets' do
    expect(/[^a-c\H]+/).to\
    become(/[0-9A-Fd-f]+/).and keep_matching('zxa3ne', with_results: %w[3 e])
  end

  it 'does not expand types that work the same in javascript' do
    expect(/[\d]+/).to stay_the_same.and keep_matching('ab34cd', with_results: %w[34])
  end

  it 'expands subsequent hex types with merging' do
    expect(/[\d\h]+/).to\
    become(/[0-9A-Fa-f]+/).and keep_matching('zxa3ne', with_results: %w[a3 e])
  end

  it 'handles posix classes in sets' do
    expect(/[äöüß[:ascii:]]+/)
      .to keep_matching('ñbäõ_ß', with_results: %w[bä _ß])
  end

  it 'handles negative posix classes in sets' do
    expect(/[x-z[:^ascii:]]+/)
      .to generate_warning('large astral plane match of set')
      .and keep_matching('xañbäõ_ß', with_results: %w[x ñ äõ ß])
  end

  it 'handles \p-style properties in sets' do
    expect(/[äöüß\p{ascii}]+/)
      .to keep_matching('ñbäõ_ß', with_results: %w[bä _ß])
  end

  it 'removes the parent set if it is depleted after extractions are done' do
    expect(/[[a-z]]+/).to\
    become(/[a-z]+/).and keep_matching('abc', with_results: %w[abc])
  end

  it 'handles properties in negative sets' do
    expect(/[^a\p{ascii}]+/)
      .to generate_warning('large astral plane match of set')
      .and keep_matching('a1ü!', with_results: %w[ü])
  end

  it 'handles set intersections' do
    expect(/[a-x&&c-z]/).to\
    become(/[c-x]/).and keep_matching('aftz', with_results: %w[f t])
  end

  it 'extracts single astral plane set members' do
    expect(/[a-z😁0-9]/)
      .to become(double(source: '(?:[0-9a-z]|\ud83d\ude01)'))
      .and keep_matching('a😐😁A', with_results: %w[a 😁])
  end

  it 'extracts 0x10000 and higher' do
    expect(/[𐀀]/).to become(double(source: '(?:\ud800\udc00)'))
  end

  it 'does not extract 0xFFFF and lower' do
    expect(/[￿]/).to stay_the_same # \uFFFF
    expect(/[￾]/).to stay_the_same # \uFFFE
  end

  it 'handles small astral plane ranges without warning' do
    expect(/[😁-😲]/).to keep_matching('a😐c', with_results: %w[😐])
  end

  it 'drops large astral plane ranges with warning' do
    expect(JsRegex::Converter)
      .to receive(:in_surrogate_pair_limit?) do |&block|
      expect(block.call).to eq(0x110000 - 0x10000)
    end.and_return(false)
    expect(/[a\u{10000}-\u{10FFFF}]/).to\
    become(/[a]/).with_warning('large astral plane match of set')
  end

  it 'does not create empty sets when dropping contents' do
    expect(/[\u{10000}-\u{10FFFF}]/).to\
    become(//).with_warning('large astral plane match of set')
  end

  it 'preserves bmp unicode ranges' do
    expect(/[字-汉]/).to stay_the_same.and keep_matching('孙孜', with_results: %w[孙 孜])
  end

  it 'preserves the backspace pseudo set' do
    expect(/[x\b]/).to stay_the_same.and keep_matching("a\bz", with_results: %W[\b])
  end

  it 'preserves the backspace pseudo set in negated sets' do
    expect(/[^x\b]/).to stay_the_same.and keep_matching("a\bz", with_results: %w[a z])
  end

  it 'converts literal newline members into newline escapes' do
    expect(/[
a
b
]/).to\
    become(/[\na\nb\n]/).and keep_matching("x\ny", with_results: %W[\n])
  end

  it 'preserves newline escape members' do
    expect(/[a\nb]/).to stay_the_same.and keep_matching("x\ny", with_results: %W[\n])
  end

  it 'adds case-swapped literal member dupes if subject to a local i-option' do
    expect(/[a](?i)[a[b]](?-i:[a](?i:[^a-fG-Y]))/).to\
    become(/[a][ABab](?:[a](?:[\x00-\uD7FF\uE000-\uFFFF]))/)
      .with_warning('large astral plane match of set')
      .and keep_matching('aAaZ', with_results: %w[aAaZ])
      .and keep_not_matching('AAaZ')
  end

  it 'does not add case-swapped members if everything is i anyway' do
    expect(/[a][a[b]][^A]/i).to\
    become(/[a][ab][^A]/i).and keep_matching('ABZ', with_results: %w[ABZ])
  end

  it 'warns for locally case-sensitive sets' do
    expect(/(?-i:[a])/i).to\
    become(/(?:[a])/i).with_warning('nested case-sensitive set')
  end

  it 'does not add duplicates for literal members that cant be swapped' do
    expect(/(?i:[A1_B])/).to\
    become(/(?:[1AB_ab])/).and keep_matching('1', with_results: %w[1])
  end
end
