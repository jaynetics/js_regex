# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::SetConverter do
  it 'preserves hex escape members' do
    given_the_ruby_regexp(/[\x41]/)
    expect_js_regex_to_be(/[\x41]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ABC', with_results: %w[A])
  end

  it 'preserves hex escape ranges' do
    given_the_ruby_regexp(/[\x41-\x43]+/)
    expect_js_regex_to_be(/[\x41-\x43]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ABC', with_results: %w[ABC])
  end

  context 'when sets are nested' do
    it 'flattens simple nested sets' do
      given_the_ruby_regexp(/[a-z[0-9]]+/)
      expect_js_regex_to_be(/[0-9a-z]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ab_12', with_results: %w[ab 12])
    end

    it 'handles nested sets in negative sets' do
      given_the_ruby_regexp(/[^a-c[0-9]]+/)
      expect_js_regex_to_be(/[\x00-\/:-`d-\uD7FF\uE000-\uFFFF]+/)
      expect_warning('astral plane')
      expect_ruby_and_js_to_match(string: 'abc123xyz', with_results: %w[xyz])
    end

    it 'isnt distracted by escaped brackets' do
      given_the_ruby_regexp(/[a-z\][0-9\[]ä-ü]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: ']a_1[', with_results: %w(]a 1[))
    end

    it 'handles negative sets nested in negative sets' do
      given_the_ruby_regexp(/[^a[^b]]+/) # matches any non-a that is non-non-b..
      expect_js_regex_to_be(/[b]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc', with_results: %w[b])
    end

    it 'can flatten multiple nested sets' do
      given_the_ruby_regexp(/[[a-c][x-z][0-2]]+/)
      expect_js_regex_to_be(/[0-2a-cx-z]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[b x 12])
    end

    it 'can flatten multiple sets nested in negative sets' do
      given_the_ruby_regexp(/[^a-c[x-z][0-2]]+/)
      expect_js_regex_to_be(/[\x00-\/3-`d-w{-\uD7FF\uE000-\uFFFF]+/)
      expect_warning('astral plane')
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[m _ 3])
    end

    it 'can flatten deeply nested sets' do
      given_the_ruby_regexp(/[a-c[x-z[0-2]]]+/)
      expect_js_regex_to_be(/[0-2a-cx-z]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[b x 12])
    end

    it 'can flatten deeply nested sets in negative sets' do
      given_the_ruby_regexp(/[^a-c[x-z[0-2]]]+/)
      expect_js_regex_to_be(/[\x00-\/3-`d-w{-\uD7FF\uE000-\uFFFF]+/)
      expect_warning('astral plane')
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[m _ 3])
    end

    it 'can handle deeply nested negative sets' do
      given_the_ruby_regexp(/[a-c[x-z[^0-2]]]+/)
      expect_js_regex_to_be(/[\x00-\/3-\uD7FF\uE000-\uFFFF]+/)
      expect_warning('astral plane')
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[bmx_ 3])
    end

    it 'can handle deeply nested negative sets in negated sets' do
      given_the_ruby_regexp(/[^a-c[x-z[^0-2]]]+/)
      expect_js_regex_to_be(/[0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[12])
    end

    it 'can handle deeply nested negative sets with properties' do
      given_the_ruby_regexp(/[^a-c[x-z[^\p{ascii}]]]+/)
      expect_js_regex_to_be(/[\x00-`d-w{-\x7F]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[m _123])
    end
  end

  it 'expands the hex type in positive sets' do
    given_the_ruby_regexp(/[w-y\h]+/)
    expect_js_regex_to_be(/[0-9A-Fa-fw-y]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w[xa3])
  end

  it 'handles the non-hex type in positive sets' do
    given_the_ruby_regexp(/[a-c\H]+/)
    expect_js_regex_to_be(/[\x00-\/:-@G-cg-\uD7FF\uE000-\uFFFF]+/)
    expect_warning('astral plane')
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w[zxa n])
  end

  it 'handles the hex type in negative sets' do
    given_the_ruby_regexp(/[^x-y\h]+/)
    expect_warning('astral plane')
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w[z n])
  end

  it 'handles the non-hex type in negative sets' do
    given_the_ruby_regexp(/[^a-c\H]+/)
    expect_js_regex_to_be(/[0-9A-Fd-f]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3ne', with_results: %w[3 e])
  end

  it 'handles posix classes in sets' do
    given_the_ruby_regexp(/[äöüß[:ascii:]]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ñbäõ_ß', with_results: %w[bä _ß])
  end

  it 'handles negative posix classes in sets' do
    given_the_ruby_regexp(/[x-z[:^ascii:]]+/)
    expect_warning('astral plane')
    expect_ruby_and_js_to_match(string: 'xañbäõ_ß', with_results: %w[x ñ äõ ß])
  end

  it 'handles \p-style properties in sets' do
    given_the_ruby_regexp(/[äöüß\p{ascii}]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ñbäõ_ß', with_results: %w[bä _ß])
  end

  it 'removes the parent set if it is depleted after extractions are done' do
    given_the_ruby_regexp(/[[a-z]]+/)
    expect_js_regex_to_be(/[a-z]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[abc])
  end

  it 'handles properties in negative sets' do
    given_the_ruby_regexp(/[^a\p{ascii}]+/)
    expect_warning('astral plane')
    expect_ruby_and_js_to_match(string: 'a1ü!', with_results: %w[ü])
  end

  it 'handles set intersections' do
    given_the_ruby_regexp(/[a-x&&c-z]/)
    expect_js_regex_to_be(/[c-x]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aftz', with_results: %w[f t])
  end

  it 'extracts single astral plane set members' do
    given_the_ruby_regexp(/[a-z😁0-9]/)
    expect(js_regex_source).to eq('(?:[0-9a-z]|\ud83d\ude01)')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a😐😁A', with_results: %w[a 😁])
  end

  it 'handles small astral plane ranges without warning' do
    given_the_ruby_regexp(/[😁-😲]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a😐c', with_results: %w[😐])
  end

  it 'drops large astral plane ranges with warning' do
    given_the_ruby_regexp(/[a\u{10000}-\u{10FFFF}]/)
    expect_js_regex_to_be(/[a]/)
    expect_warning('astral plane')
  end

  it 'does not create empty sets when dropping contents' do
    given_the_ruby_regexp(/[\u{10000}-\u{10FFFF}]/)
    expect_js_regex_to_be(//)
    expect_warning('astral plane')
  end

  it 'preserves bmp unicode ranges' do
    # current javascript versions support these
    given_the_ruby_regexp(/[字-汉]/)
    expect_js_regex_to_be(/[字-汉]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '孙孜', with_results: %w[孙 孜])
  end

  it 'preserves the backspace pseudo set' do
    given_the_ruby_regexp(/[x\b]/)
    expect_js_regex_to_be(/[x\b]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "a\bz", with_results: %W[\b])
  end

  it 'preserves the backspace pseudo set in negated sets' do
    given_the_ruby_regexp(/[^x\b]/)
    expect_js_regex_to_be(/[^x\b]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "a\bz", with_results: %w[a z])
  end

  it 'converts literal newline members into newline escapes' do
    given_the_ruby_regexp(/[a
b]/)
    expect_js_regex_to_be(/[a\nb]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "x\ny", with_results: %W[\n])
  end

  it 'preserves newline escape members' do
    given_the_ruby_regexp(/[a\nb]/)
    expect_js_regex_to_be(/[a\nb]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "x\ny", with_results: %W[\n])
  end

  it 'adds case-swapped literal member dupes if subject to a local i-option' do
    given_the_ruby_regexp(/[a](?i)[a](?-i:[a](?i:[^a-fG-Y]))/)
    expect_js_regex_to_be(/[a][Aa]([a]([\x00-\uD7FF\uE000-\uFFFF]))/)
    expect_warning('astral plane')
    expect_ruby_and_js_to_match(string: 'aAaZ', with_results: %w[aAaZ])
    expect_ruby_and_js_not_to_match(string: 'AAaZ')
  end

  it 'does not add duplicates for literal members that cant be swapped' do
    given_the_ruby_regexp(/(?i:[A1_B])/)
    expect_js_regex_to_be(/([1AB_ab])/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '1', with_results: %w[1])
  end
end
