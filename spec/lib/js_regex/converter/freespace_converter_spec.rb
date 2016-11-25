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

    it 'does not drop escaped whitespace literals' do
      given_the_ruby_regexp(/Escaped\	Whitespace\ !/x)
      expect_js_regex_to_be(/Escaped\tWhitespace\ !/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:        'Escaped	Whitespace !',
                                  with_results: ['Escaped	Whitespace !'])
    end
  end

  context 'when extended mode is not set' do
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
