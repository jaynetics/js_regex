# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::GroupConverter do
  it 'preserves capturing groups' do
    given_the_ruby_regexp(/(abc)/)
    expect_js_regex_to_be(/(abc)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[abc])
  end

  it 'sets Node#reference for SecondPass lookups' do
    group = Regexp::Parser.parse(/(abc)/)[0]

    result = JsRegex::Converter.convert(group)

    expect(result).to be_a JsRegex::Node
    expect(result.type).to eq(:captured_group)
    expect(result.reference).to eq(1)
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

  it 'drops switch groups without warning' do
    given_the_ruby_regexp(/a(?m-x)a/)
    expect_js_regex_to_be(/aa/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aa', with_results: %w[aa])
  end

  it 'drops all encoding options with warning' do
    given_the_ruby_regexp(Regexp.new('a(?adu:a)a'))
    expect_js_regex_to_be(/a(?:a)a/)
    expect_warning('encoding options ["a", "d", "u"]')
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
    given_the_token(:group, :unknown)
    expect_js_regex_to_be(/(?:)/)
    expect_warning
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

  context 'when dealing with absence groups',
    if: (Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.4.1')) do

    it 'converts simple cases to complimentary alternations' do
      given_the_ruby_regexp(Regexp.new('1(?~23)4'))
      expect_js_regex_to_be(/1(?:(?:.|\n){,1}|(?:(?!23)(?:.|\n))*)4/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: '1234')
      expect_ruby_and_js_not_to_match(string: '12234')
      expect_ruby_and_js_to_match(string: '14')
      expect_ruby_and_js_to_match(string: '124')
      expect_ruby_and_js_to_match(string: '134')
      expect_ruby_and_js_to_match(string: '12224')
      expect_ruby_and_js_to_match(string: '13334')
    end

    it 'can handle fixed quantifications' do
      given_the_ruby_regexp(Regexp.new('A(?~\d{4})Z'))
      expect_js_regex_to_be(/A(?:(?:.|\n){,3}|(?:(?!\d{4})(?:.|\n))*)Z/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'A1234Z')
      expect_ruby_and_js_to_match(string: 'AZ')
      expect_ruby_and_js_to_match(string: 'A123Z')
      expect_ruby_and_js_to_match(string: 'A12X34Z')
    end

    it 'drops variably quantified cases with warning' do
      given_the_ruby_regexp(Regexp.new('1(?~2+)3'))
      expect_js_regex_to_be(/13/)
      expect_warning('variable-length absence group content')
    end

    it 'drops other variable length cases with warning' do
      given_the_ruby_regexp(Regexp.new('1(?~2|22)3'))
      expect_js_regex_to_be(/13/)
      expect_warning('variable-length absence group content')
    end

    it 'converts unmatchable cases to an unmatchable group' do
      given_the_ruby_regexp(Regexp.new('1(?~)2'))
      expect_js_regex_to_be(/1(?!)2/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: '12')
      expect_ruby_and_js_not_to_match(string: '1X2')
    end
  end
end
