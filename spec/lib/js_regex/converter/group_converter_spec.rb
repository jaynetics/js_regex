# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::GroupConverter do
  it 'preserves capturing groups' do
    given_the_ruby_regexp(/(abc)/)
    expect_js_regex_to_be(/(abc)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[abc])
  end

  it 'preserves passive groups' do
    given_the_ruby_regexp(/(?:abc)/)
    expect_js_regex_to_be(/(?:abc)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[abc])
  end

  it 'removes names from ab-named groups' do
    given_the_ruby_regexp(/(?<protocol>http|ftp)/)
    expect_js_regex_to_be(/(http|ftp)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ftp', with_results: %w[ftp])
  end

  it 'removes names from sq-named groups' do
    given_the_ruby_regexp(/(?'protocol'http|ftp)/)
    expect_js_regex_to_be(/(http|ftp)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ftp', with_results: %w[ftp])
  end

  it 'removes comment groups' do
    given_the_ruby_regexp(/a(?# <- this matches 'a')/)
    expect_js_regex_to_be(/a/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a a a', with_results: %w[a a a])
  end

  it 'drops group-specific options with warning' do
    given_the_ruby_regexp(/a(?i-m:a)a/m)
    expect_js_regex_to_be(/a(a)a/)
    expect_warning('group-specific options')
  end

  it 'works following positive lookbehind assertions' do
    # c.f. assertion_converter_spec.rb
    given_the_ruby_regexp(/(?<=A)(abc)/)
    expect_js_regex_to_be(/(?:A)(abc)/)
    expect_warning
  end

  it 'works following negative lookbehind assertions' do
    # c.f. assertion_converter_spec.rb
    given_the_ruby_regexp(/(?<!A)(abc)/)
    expect_js_regex_to_be(/(abc)/)
    expect_warning
  end

  it 'opens passive groups for unknown group heads' do
    ep = expression_double({ type: :group, token: :unknown, to_s: '(%', ts: 0 })
    converter = JsRegex::Converter.for(ep)
    expect(converter).to be_a(described_class)

    context = JsRegex::Converter::Context.new(//)
    source = converter.convert(ep, context)
    expect(source).to start_with('(?:')
    expect(context.warnings.size).to eq(1)
  end

  context 'when dealing with atomic groups' do
    # Atomicity is emulated using backreferenced lookahead groups:
    # http://instanceof.me/post/52245507631
    # regex-emulate-atomic-grouping-with-lookahead
    it 'emulates them using backreferenced lookahead groups' do
      given_the_ruby_regexp(/1(?>33|3)37/)
      expect_js_regex_to_be(/1(?=(33|3))\1(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: '1337')
      expect_ruby_and_js_to_match(string: '13337', with_results: ['13337'])
    end

    it 'can handle multiple atomic groups' do
      given_the_ruby_regexp(/(?>33|3)(?:3)(?>33|3)3/)
      expect_js_regex_to_be(/(?=(33|3))\1(?:)(?:3)(?=(33|3))\2(?:)3/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: '3333')
      expect_ruby_and_js_to_match(string: '333333', with_results: ['333333'])
    end

    it 'can handle atomic groups nested in non-atomic groups' do
      given_the_ruby_regexp(/1((?>33|3))37/)
      expect_js_regex_to_be(/1((?=(33|3))\2(?:))37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: '1337')
      expect_ruby_and_js_to_match(string: '13337')
    end

    it 'makes atomic groups nested in atomic groups non-atomic with warning' do
      given_the_ruby_regexp(/1(?>(?>33|3))37/)
      expect_js_regex_to_be(/1(?=((?:33|3)))\1(?:)37/)
      expect_warning('nested atomic group')
    end

    it 'takes into account preceding active groups for the backreference' do
      given_the_ruby_regexp(/(a(b))_1(?>33|3)37/)
      expect_js_regex_to_be(/(a(b))_1(?=(33|3))\3(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'ab_1337')
      expect_ruby_and_js_to_match(string: 'ab_13337')
    end

    it 'isnt confused by preceding passive groups' do
      given_the_ruby_regexp(/(?:c)_1(?>33|3)37/)
      expect_js_regex_to_be(/(?:c)_1(?=(33|3))\1(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'c_1337')
      expect_ruby_and_js_to_match(string: 'c_13337')
    end

    it 'isnt confused by preceding lookahead groups' do
      given_the_ruby_regexp(/(?=c)_1(?>33|3)37/)
      expect_js_regex_to_be(/(?=c)_1(?=(33|3))\1(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'c_1337')
      # Ruby won't match 'c_13337' as of v2.3.3 - maybe this is a bug.
    end

    it 'isnt confused by preceding negative lookahead groups' do
      given_the_ruby_regexp(/(?!=x)_1(?>33|3)37/)
      expect_js_regex_to_be(/(?!=x)_1(?=(33|3))\1(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'c_1337')
      expect_ruby_and_js_to_match(string: 'c_13337')
    end
  end

  it 'drops absence operators / groups with warning',
     if: ruby_version_at_least?('2.4.1') do
    given_the_ruby_regexp(Regexp.new('1(?~2)3'))
    expect_js_regex_to_be(/13/)
    expect_warning("Dropped unsupported absence group '(?~2)' at index 1")
  end
end
