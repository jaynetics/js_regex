# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::GroupConverter do
  it 'removes names from ab-named groups' do
    given_the_ruby_regexp(/(?<protocol>http|ftp)/)
    expect_js_regex_to_be(/(http|ftp)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ftp', with_results: %w(ftp))
  end

  it 'removes names from sq-named groups' do
    given_the_ruby_regexp(/(?'protocol'http|ftp)/)
    expect_js_regex_to_be(/(http|ftp)/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ftp', with_results: %w(ftp))
  end

  it 'removes comment groups' do
    given_the_ruby_regexp(/a(?# <- this matches 'a')/)
    expect_js_regex_to_be(/a/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a a a', with_results: %w(a a a))
  end

  it 'drops group-specific options with warning' do
    given_the_ruby_regexp(/a(?i-m:a)a/m)
    expect_js_regex_to_be(/a(a)a/)
    expect_warning
  end

  context 'when dealing with atomic groups' do
    it 'emulates them using backreferenced lookahead groups' do
      given_the_ruby_regexp(/1(?>33|3)37/)
      expect_js_regex_to_be(/1(?=(33|3))\1(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '1337', with_results: [])
      expect_ruby_and_js_to_match(string: '13337', with_results: ['13337'])
    end

    it 'takes into account preceding active groups for the backreference' do
      given_the_ruby_regexp(/(a(b))_1(?>33|3)37/)
      expect_js_regex_to_be(/(a(b))_1(?=(33|3))\3(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ab_1337', with_results: [])
      expect_ruby_and_js_to_match_string('ab_13337')
    end

    it 'isnt confused by preceding passive groups' do
      given_the_ruby_regexp(/(?:c)_1(?>33|3)37/)
      expect_js_regex_to_be(/(?:c)_1(?=(33|3))\1(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'c_1337', with_results: [])
      expect_ruby_and_js_to_match_string('c_13337')
    end
  end
end
