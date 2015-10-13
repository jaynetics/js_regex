
require 'spec_helper'

describe JsRegex::Converter do
  describe 'escape sequence handling' do
    it 'preserves escaped meta chars' do
      given_the_ruby_regexp(/\\A\\h/)
      expect_js_regex_to_be(/\\A\\h/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '\\A\\h', with_results: ['\\A\\h'])
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

    it 'translates the anchor \z' do
      given_the_ruby_regexp(/\w\z/)
      expect_js_regex_to_be(/\w$/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
    end

    it 'translates the anchor \Z' do
      given_the_ruby_regexp(/\w\Z/)
      expect_js_regex_to_be(/\w(?=\n?$)/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc', with_results: %w(c))
      expect_ruby_and_js_to_match(string: "abc\n", with_results: %w(c))
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
  end
end
