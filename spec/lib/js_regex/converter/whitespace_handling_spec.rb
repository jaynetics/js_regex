# encoding: utf-8

#
#
#
# WARNING: Some of the examples below contain literal tabs.
# Make sure that your IDE doesn't replace them with spaces.
#
#
#

require 'spec_helper'

describe JsRegex::Converter do
  describe 'whitespace handling' do
    it 'replaces literal carriage returns with \r' do
      carriage_return = "\r"
      given_the_ruby_regexp(/#{carriage_return}/)
      expect_js_regex_to_be(/\r/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: "\r", with_results: ["\r"])
    end

    it 'replaces literal form feeds with \f' do
      form_feed = "\f"
      given_the_ruby_regexp(/#{form_feed}/)
      expect_js_regex_to_be(/\f/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: "\f", with_results: ["\f"])
    end

    it 'replaces literal newlines with \n' do
      given_the_ruby_regexp(/
/)
      expect_js_regex_to_be(/\n/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: "\n", with_results: ["\n"])
    end

    it 'replaces literal tabs with \t' do
      given_the_ruby_regexp(/	/)
      expect_js_regex_to_be(/\t/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '	', with_results: ['	'])
    end

    it 'replaces literal tabs that are part of escapes with \t' do
      given_the_ruby_regexp(/\	/)
      expect_js_regex_to_be(/\t/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '	', with_results: ['	'])
    end

    context 'when extended mode is set' do
      it 'preserves escaped whitespace literals' do
        given_the_ruby_regexp(/Escaped\	Whitespace\ !/x)
        expect_js_regex_to_be(/Escaped\tWhitespace\ !/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'Escaped	Whitespace !',
                                    with_results: ['Escaped	Whitespace !'])
      end

      it 'drops non-escaped whitespace literals' do
        given_the_ruby_regexp(/	Unescaped  Whitespace!	/x)
        expect_js_regex_to_be(/UnescapedWhitespace!/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'UnescapedWhitespace!',
                                    with_results: ['UnescapedWhitespace!'])
      end
    end

    context 'when extended mode is not set' do
      it 'preserves escaped whitespace literals' do
        given_the_ruby_regexp(/Escaped\	Whitespace\ !/)
        expect_js_regex_to_be(/Escaped\tWhitespace\ !/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'Escaped	Whitespace !',
                                    with_results: ['Escaped	Whitespace !'])
      end

      it 'preserves non-escaped whitespace literals' do
        given_the_ruby_regexp(/	Unescaped  Whitespace!	/)
        expect_js_regex_to_be(/\tUnescaped  Whitespace!\t/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '	Unescaped  Whitespace!	',
                                    with_results: ['	Unescaped  Whitespace!	'])
      end
    end
  end
end
