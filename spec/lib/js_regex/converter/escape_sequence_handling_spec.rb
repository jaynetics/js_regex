# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter do
  describe 'escape sequence handling' do
    it 'lets backslashes pass through' do
      given_the_ruby_regexp(/\\/)
      expect_js_regex_to_be(/\\/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '\\', with_results: %w(\\))
    end

    it 'preserves escaped meta chars' do
      given_the_ruby_regexp(/\\A\\h/)
      expect_js_regex_to_be(/\\A\\h/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '\\A\\h', with_results: ['\\A\\h'])
    end

    it 'lets ascii escapes pass through' do
      given_the_ruby_regexp(/\x42/)
      expect_js_regex_to_be(/\x42/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ABC', with_results: ['B'])
    end

    it 'lets unicode / codepoint escapes pass through' do
      given_the_ruby_regexp(/\u263A/)
      expect_js_regex_to_be(/\u263A/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'A☺C', with_results: ['☺'])
    end

    it 'translates the hex type \h' do
      given_the_ruby_regexp(/\h+/)
      expect_js_regex_to_be(/[A-Fa-f0-9]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'FF__FF', with_results: %w(FF FF))
    end

    it 'translates the nonhex type \H' do
      given_the_ruby_regexp(/\H+/)
      expect_js_regex_to_be(/[^A-Fa-f0-9]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'FFxy66z', with_results: %w(xy z))
    end

    it 'translates the beginning-of-string anchor \A' do
      given_the_ruby_regexp(/\A\d/)
      expect_js_regex_to_be(/^\d/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '123', with_results: %w(1))
    end

    it 'translates the end-of-string anchor \z' do
      given_the_ruby_regexp(/\w\z/)
      expect_js_regex_to_be(/\w$/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
    end

    it 'translates the end-of-string-with-optional-newline anchor \Z' do
      given_the_ruby_regexp(/\w\Z/)
      expect_js_regex_to_be(/\w(?=\n?$)/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
      expect_ruby_and_js_to_match(string: "abc\n", with_results: %w(c))
    end

    it 'preserves the word-boundary \b' do
      given_the_ruby_regexp(/\w\b/)
      expect_js_regex_to_be(/\w\b/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
    end

    it 'preserves the non-word-boundary \B' do
      given_the_ruby_regexp(/\w\B/)
      expect_js_regex_to_be(/\w\B/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc', with_results: %w(a b))
    end

    it 'drops the bell char \a with warning' do
      given_the_ruby_regexp(/.\a/)
      expect_js_regex_to_be(/./)
      expect_warning
    end

    it 'drops the escape char \e with warning' do
      given_the_ruby_regexp(/.\e/)
      expect_js_regex_to_be(/./)
      expect_warning
    end

    it 'drops control sequences of the style \C-x with warning' do
      given_the_ruby_regexp(/.\C-d/)
      expect_js_regex_to_be(/./)
      expect_warning
    end

    it 'drops control sequences of the style \cX with warning' do
      given_the_ruby_regexp(/.\cD/)
      expect_js_regex_to_be(/./)
      expect_warning
    end

    it 'drops the subexpression rematcher \G with warning' do
      given_the_ruby_regexp(/(.)\G/)
      expect_js_regex_to_be(/(.)/)
      expect_warning
    end

    it 'drops ab-named subexpression calls (\g) with warning' do
      given_the_ruby_regexp(/(?<x>.)\g<x>/)
      expect_js_regex_to_be(/(.)/)
      expect_warning
    end

    it 'drops sq-named subexpression calls (\g) with warning' do
      given_the_ruby_regexp(/(?'x'.)\g'x'/)
      expect_js_regex_to_be(/(.)/)
      expect_warning
    end

    it 'drops the keep / lookbehind marker \K with warning' do
      given_the_ruby_regexp(/a\Kb/)
      expect_js_regex_to_be(/ab/)
      expect_warning
    end

    it 'preserves simple number backreferences' do
      given_the_ruby_regexp(/(a)\1/)
      expect_js_regex_to_be(/(a)\1/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'a', with_results: [])
      expect_ruby_and_js_to_match_string('aa')
    end

    it 'drops ab-numbered backreferences (\k) with warning' do
      given_the_ruby_regexp(/(a)\k<1>/)
      expect_js_regex_to_be(/(a)/)
      expect_warning
    end

    it 'drops sq-numbered backreferences (\k) with warning' do
      given_the_ruby_regexp(/(a)\k'1'/)
      expect_js_regex_to_be(/(a)/)
      expect_warning
    end

    it 'preservers carriage returns' do
      given_the_ruby_regexp(/\r/)
      expect_js_regex_to_be(/\r/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: "abc\r123", with_results: ["\r"])
    end
  end
end
