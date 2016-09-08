# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter do
  describe 'literal handling' do
    it 'converts literal newlines into newline escapes' do
      given_the_ruby_regexp(/

/)
      expect_js_regex_to_be(/\n\n/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: "a\n\nb", with_results: ["\n\n"])
    end

    it 'does not add escapes to \\n' do
      given_the_ruby_regexp(/\\n/)
      expect_js_regex_to_be(/\\n/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: '\\n', with_results: %w(\\n))
    end

    it 'converts literal forward slashes to forward slash escapes' do
      given_the_ruby_regexp(%r{//})
      expect(@js_regex.source).to eq('\\/\\/')
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'a//b', with_results: %w(//))
    end

    it 'drops astral plane literals with warning' do
      given_the_ruby_regexp(/😁/)
      expect_js_regex_to_be(//)
      expect_warning
    end

    it 'lets all other literals pass through' do
      given_the_ruby_regexp(/aü_1>!/)
      expect_js_regex_to_be(/aü_1>!/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'aü_1>!', with_results: %w(aü_1>!))
    end
  end
end
