
require 'spec_helper'

describe JsRegex::Converter do
  describe 'capture group handling' do
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

    it 'emulates atomic groups with backreferenced lookahead groups' do
      given_the_ruby_regexp(/1(?>33|3)37/)
      expect_js_regex_to_be(/1(?=(33|3))\1(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '1337', with_results: [])
      expect_ruby_and_js_to_match(string: '13337', with_results: ['13337'])
    end

    it 'makes conditional groups non-conditional with warning' do
      given_the_ruby_regexp(/(a)?(?(1)b|c)/)
      expect_js_regex_to_be(/(a)?(b|c)/)
      expect_warning
    end

    it 'makes ab-named conditional groups non-conditional with warning' do
      given_the_ruby_regexp(/(?<condition>a)?(?(<condition>)b|c)/)
      expect_js_regex_to_be(/(a)?(b|c)/)
      expect_warning
    end

    it 'makes sq-named conditional groups non-conditional with warning' do
      given_the_ruby_regexp(/(?'condition'a)?(?('condition')b|c)/)
      expect_js_regex_to_be(/(a)?(b|c)/)
      expect_warning
    end

    it 'makes lookbehind groups non-lookbehind with warning' do
      given_the_ruby_regexp(/(?<=A)b/)
      expect_js_regex_to_be(/(?:A)b/)
      expect_warning
    end

    it 'drops group-specific options with warning' do
      given_the_ruby_regexp(/a(?i-m:a)a/m)
      expect_js_regex_to_be(/a(a)a/)
      expect_warning
    end
  end
end
