# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::SetConverter do
  context 'when sets are nested' do
    it 'flattens simple nested sets' do
      given_the_ruby_regexp(/[a-z[0-9]]+/)
      expect_js_regex_to_be(/[a-z0-9]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ab_12', with_results: %w(ab 12))
    end

    it 'flattens nested sets in negative sets' do
      given_the_ruby_regexp(/[^a-c[0-9]]+/)
      expect_js_regex_to_be(/[^a-c0-9]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc123xyz', with_results: %w(xyz))
    end

    it 'isnt distracted by escaped brackets' do
      given_the_ruby_regexp(/[a-z\][0-9\[]ä-ü]+/)
      expect_js_regex_to_be(/[a-z\]0-9\[ä-ü]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: ']a_1[', with_results: %w(]a 1[))
    end

    it 'drops negative nested sets from negative sets' do
      given_the_ruby_regexp(/[^a[^b]]+/) # matches any non-a that is b, i.e. b
      expect_js_regex_to_be(/[^a]+/)
      expect_warning
    end

    it 'can flatten multiple nested sets' do
      given_the_ruby_regexp(/[[a-c][x-z][0-2]]+/)
      expect_js_regex_to_be(/[a-cx-z0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w(b x 12))
    end

    it 'can flatten multiple sets nested in negative sets' do
      given_the_ruby_regexp(/[^a-c[x-z][0-2]]+/)
      expect_js_regex_to_be(/[^a-cx-z0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w(m _ 3))
    end

    it 'can flatten deeply nested sets' do
      given_the_ruby_regexp(/[a-c[x-z[0-2]]]+/)
      expect_js_regex_to_be(/[a-cx-z0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w(b x 12))
    end

    it 'can flatten deeply nested sets in negative sets' do
      given_the_ruby_regexp(/[^a-c[x-z[0-2]]]+/)
      expect_js_regex_to_be(/[^a-cx-z0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w(m _ 3))
    end

    it 'drops deeply nested negative sets with warning' do
      given_the_ruby_regexp(/[a-c[x-z[^0-2]]]+/)
      expect_js_regex_to_be(/[a-cx-z]+/)
      expect_warning
    end

    it 'drops deeply nested negative sets from negated sets with warning' do
      given_the_ruby_regexp(/[^a-c[x-z[^0-2]]]+/)
      expect_js_regex_to_be(/[^a-cx-z]+/)
      expect_warning
    end
  end

  it 'extracts the hex type from sets' do
    given_the_ruby_regexp(/[x-y\h]+/)
    expect_js_regex_to_be(/(?:[x-y]|[A-Fa-f0-9])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w(xa3))
  end

  it 'extracts the non-hex type from sets' do
    given_the_ruby_regexp(/[x-y\H]+/)
    expect_js_regex_to_be(/(?:[x-y]|[^A-Fa-f0-9])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w(zx n))
  end

  it 'extracts posix classes from sets' do
    given_the_ruby_regexp(/[äöüß[:ascii:]]+/)
    expect_js_regex_to_be(/(?:[äöüß]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ñbäõ_ß', with_results: %w(bä _ß))
  end

  it 'extracts \p-style properties from sets' do
    given_the_ruby_regexp(/[äöüß\p{ascii}]+/)
    expect_js_regex_to_be(/(?:[äöüß]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ñbäõ_ß', with_results: %w(bä _ß))
  end

  it 'extracts negative posix classes from sets' do
    given_the_ruby_regexp(/[x-z[:^ascii:]]+/)
    expect_js_regex_to_be(/(?:[x-z]|[^\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'xañbäõ_ß', with_results: %w(x ñ äõ ß))
  end

  it 'wraps multiple set extractions in a passive alternation group' do
    given_the_ruby_regexp(/[\h\p{ascii}]+/)
    expect_js_regex_to_be(/(?:[A-Fa-f0-9]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'efghß', with_results: %w(efgh))
  end

  it 'removes the parent set if it is depleted after extractions are done' do
    given_the_ruby_regexp(/[[a-z]]+/)
    expect_js_regex_to_be(/[a-z]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w(abc))
  end

  it 'drops set intersections with warning' do
    given_the_ruby_regexp(/[a-c&&x-z]/)
    expect_js_regex_to_be(/[a-cx-z]/)
    expect_warning
  end

  it 'drops astral plane chars with warning' do
    # FIXME: If the astral plane chars form a range
    # Regexp::Scanner will not detect them as a range,
    # instead seeing 3 separate members.
    # The '-' will survive processing, causing Ruby
    # to warn on STDOUT and the set to match '-'.
    # This should be fixed in Regexp::Scanner itself.
    given_the_ruby_regexp(/[a-z😁0-9]/)
    expect_js_regex_to_be(/[a-z0-9]/)
    expect_warning
  end

  it 'preserves bmp unicode ranges' do
    # current javascript versions support these
    given_the_ruby_regexp(/[字-汉]/)
    expect_js_regex_to_be(/[字-汉]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '孙孜', with_results: %w(孙 孜))
  end

  it 'drops the backspace pseudo set with warning' do
    given_the_ruby_regexp(/[\b]./)
    expect_js_regex_to_be(/./)
    expect_warning
  end

  it 'converts literal newline members into newline escapes' do
    given_the_ruby_regexp(/[a
b]/)
    expect_js_regex_to_be(/[a\nb]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "x\ny", with_results: ["\n"])
  end

  it 'preserves newline escape members' do
    given_the_ruby_regexp(/[a\nb]/)
    expect_js_regex_to_be(/[a\nb]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "x\ny", with_results: ["\n"])
  end

  it 'does not add escapes to \\n' do
    given_the_ruby_regexp(/\\n/)
    expect_js_regex_to_be(/\\n/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '\\n', with_results: %w(\\n))
  end
end
