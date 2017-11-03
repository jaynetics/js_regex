# encoding: utf-8
# frozen_string_literal: true

#
#
#
# WARNING: Some of the examples below contain literal tabs.
# Make sure that your IDE doesn't replace them with spaces.
#
#
#

require 'spec_helper'

describe JsRegex::Converter::FreespaceConverter do
  context 'when extended mode is set' do
    it 'drops comments and whitespace' do
      given_the_ruby_regexp(/Multiple    #   comment 1
                             Comments!   #   comment 2
                            /x)
      expect_js_regex_to_be(/MultipleComments!/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        'MultipleComments!',
                                  with_results: ['MultipleComments!'])
    end

    it 'drops whitespace literals' do
      given_the_ruby_regexp(/	Unescaped  Whitespace!	/x)
      expect_js_regex_to_be(/UnescapedWhitespace!/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        'UnescapedWhitespace!',
                                  with_results: ['UnescapedWhitespace!'])
    end

    it 'drops whitespace in extended-mode groups' do
      given_the_ruby_regexp(/ He(?x: ll )o /)
      expect_js_regex_to_be(/ He(ll)o /)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        ' Hello ',
                                  with_results: [' Hello '])
    end

    it 'drops whitespace after extended-mode switches' do
      given_the_ruby_regexp(/ He ll(?x) o /)
      expect_js_regex_to_be(/ He llo/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        ' He llo',
                                  with_results: [' He llo'])
    end

    it 'does not drop escaped whitespace literals' do
      given_the_ruby_regexp(/Escaped\	Whitespace\ !/x)
      expect_js_regex_to_be(/Escaped\tWhitespace\ !/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        'Escaped	Whitespace !',
                                  with_results: ['Escaped	Whitespace !'])
    end

    it 'does not drop whitespace in non-extended-mode groups' do
      given_the_ruby_regexp(/ He(?-x: ll )o /x)
      expect_js_regex_to_be(/He( ll )o/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        'He ll o',
                                  with_results: ['He ll o'])
    end

    it 'does not drop whitespace after non-extended-mode switches' do
      given_the_ruby_regexp(/ He ll(?-x) o /x)
      expect_js_regex_to_be(/Hell o /)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        'Hell o ',
                                  with_results: ['Hell o '])
    end
  end

  context 'when extended mode is not specified' do
    it 'does not drop comments and whitespace' do
      given_the_ruby_regexp(/Multiple    #   comment 1
                             Comments!   #   comment 2
                            /)
      expect(@js_regex.source).to include('Multiple    #   comment 1')
      expect(@js_regex.source).to include('Comments!   #   comment 2')
      expect_no_warnings
    end

    it 'does not drop whitespace literals' do
      given_the_ruby_regexp(/	Unescaped  Whitespace!	/)
      expect_js_regex_to_be(/\tUnescaped  Whitespace!\t/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        '	Unescaped  Whitespace!	',
                                  with_results: ['	Unescaped  Whitespace!	'])
    end

    it 'does not drop escaped whitespace literals' do
      given_the_ruby_regexp(/Escaped\	Whitespace\ !/)
      expect_js_regex_to_be(/Escaped\tWhitespace\ !/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        'Escaped	Whitespace !',
                                  with_results: ['Escaped	Whitespace !'])
    end
  end
end
