
require 'spec_helper'

describe JsRegex::Converter do
  describe 'options handling' do
    it 'always sets the global flag' do
      given_the_ruby_regexp(//)
      expect(@js_regex.to_h[:options]).to include('g')
    end

    it 'carries over the case-insensitive option' do
      given_the_ruby_regexp(/a/i)
      expect(@js_regex.to_h[:options]).to include('i')
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ABab', with_results: %w(A a))
    end

    it 'ensures dots match newlines if the multiline option is set' do
      given_the_ruby_regexp(/a.+a/m)
      expect_js_regex_to_be(/a(?:.|\n)+a/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abba', with_results: ['abba'])
      expect_ruby_and_js_to_match(string: "ab\nba", with_results: ["ab\nba"])
    end

    it 'does not make escaped dots match newlines in multiline mode' do
      given_the_ruby_regexp(/a\.+a/m)
      expect_js_regex_to_be(/a\.+a/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'aba a.a', with_results: ['a.a'])
      expect_ruby_and_js_to_match(string: "a\na a.a", with_results: ['a.a'])
    end

    context 'when extended mode is set' do
      it 'drops comments' do
        given_the_ruby_regexp(/Multiple    #   comment 1
                               Comments!   #   comment 2
                              /x)
        expect_js_regex_to_be(/MultipleComments!/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'MultipleComments!',
                                    with_results: ['MultipleComments!'])
      end

      it 'preserves escaped whitespace' do
        given_the_ruby_regexp(/Escaped\	Whitespace\ !/x)
        expect_js_regex_to_be(/Escaped\	Whitespace\ !/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'Escaped	Whitespace !',
                                    with_results: ['Escaped	Whitespace !'])
      end

      it 'drops non-escaped whitespace' do
        given_the_ruby_regexp(/	Unescaped  Whitespace!	/x)
        expect_js_regex_to_be(/UnescapedWhitespace!/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'UnescapedWhitespace!',
                                    with_results: ['UnescapedWhitespace!'])
      end
    end

    context 'when extended mode is not set' do
      it 'treats comments as literals' do
        given_the_ruby_regexp(/Multiple    #   comment 1
                               Comments!   #   comment 2
                              /)
        expect(@js_regex.source).to include('Multiple    #   comment 1')
        expect(@js_regex.source).to include('Comments!   #   comment 2')
        expect_no_warnings
      end

      it 'preserves escaped white space' do
        given_the_ruby_regexp(/Escaped\	Whitespace\ !/)
        expect_js_regex_to_be(/Escaped\	Whitespace\ !/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'Escaped	Whitespace !',
                                    with_results: ['Escaped	Whitespace !'])
      end

      it 'preserves unescaped white space' do
        given_the_ruby_regexp(/	Unescaped  Whitespace!	/)
        expect_js_regex_to_be(/	Unescaped  Whitespace!	/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '	Unescaped  Whitespace!	',
                                    with_results: ['	Unescaped  Whitespace!	'])
      end
    end
  end
end
