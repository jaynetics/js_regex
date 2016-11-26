# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::QuantifierConverter do
  context 'when quantifiers are greedy (default)' do
    it 'preserves zero-or-ones (?)' do
      given_the_ruby_regexp(/a?/)
      expect_js_regex_to_be(/a?/)
      expect_no_warnings
    end

    it 'preserves zero-or-mores (*)' do
      given_the_ruby_regexp(/a*/)
      expect_js_regex_to_be(/a*/)
      expect_no_warnings
    end

    it 'preserves one-or-mores (+)' do
      given_the_ruby_regexp(/a+/)
      expect_js_regex_to_be(/a+/)
      expect_no_warnings
    end

    it 'preserves fixes ({x})' do
      given_the_ruby_regexp(/a{4}/)
      expect_js_regex_to_be(/a{4}/)
      expect_no_warnings
    end

    it 'preserves ranges ({x,y})' do
      given_the_ruby_regexp(/a{6,8}/)
      expect_js_regex_to_be(/a{6,8}/)
      expect_no_warnings
    end

    it 'preserves set quantifiers' do
      given_the_ruby_regexp(/[a-z]{6,8}/)
      expect_js_regex_to_be(/[a-z]{6,8}/)
      expect_no_warnings
    end

    it 'preserves group quantifiers' do
      given_the_ruby_regexp(/(?:a|b){6,8}/)
      expect_js_regex_to_be(/(?:a|b){6,8}/)
      expect_no_warnings
    end
  end

  context 'when quantifiers are reluctant' do
    it 'preserves zero-or-ones (??)' do
      given_the_ruby_regexp(/a??/)
      expect_js_regex_to_be(/a??/)
      expect_no_warnings
    end

    it 'preserves zero-or-mores (*?)' do
      given_the_ruby_regexp(/a*?/)
      expect_js_regex_to_be(/a*?/)
      expect_no_warnings
    end

    it 'preserves one-or-mores (+?)' do
      given_the_ruby_regexp(/a+?/)
      expect_js_regex_to_be(/a+?/)
      expect_no_warnings
    end

    it 'preserves fixes ({x}?)' do
      given_the_ruby_regexp(/a{4}?/)
      expect_js_regex_to_be(/a{4}?/)
      expect_no_warnings
    end

    it 'preserves ranges ({x,y}?)' do
      given_the_ruby_regexp(/a{6,8}?/)
      expect_js_regex_to_be(/a{6,8}?/)
      expect_no_warnings
    end

    it 'preserves set quantifiers' do
      given_the_ruby_regexp(/[a-z]{6,8}?/)
      expect_js_regex_to_be(/[a-z]{6,8}?/)
      expect_no_warnings
    end

    it 'preserves group quantifiers' do
      given_the_ruby_regexp(/(?:a|b){6,8}?/)
      expect_js_regex_to_be(/(?:a|b){6,8}?/)
      expect_no_warnings
    end
  end

  context 'when quantifiers are possessive' do
    it 'makes zero-or-ones (?+) none-possessive with warning' do
      given_the_ruby_regexp(/a?+/)
      expect_js_regex_to_be(/a?/)
      expect_warning('possessive')
    end

    it 'makes zero-or-mores (*+) none-possessive with warning' do
      given_the_ruby_regexp(/a*+/)
      expect_js_regex_to_be(/a*/)
      expect_warning('possessive')
    end

    it 'makes one-or-mores (++) none-possessive with warning' do
      given_the_ruby_regexp(/a++/)
      expect_js_regex_to_be(/a+/)
      expect_warning('possessive')
    end

    it 'makes fixes ({x}+) none-possessive with warning' do
      given_the_ruby_regexp(/a{4}+/)
      expect_js_regex_to_be(/a{4}/)
      expect_warning('possessive')
    end

    it 'makes ranges ({x,y}+) none-possessive with warning' do
      given_the_ruby_regexp(/a{6,8}+/)
      expect_js_regex_to_be(/a{6,8}/)
      expect_warning('possessive')
    end

    it 'makes set quantifiers none-possessive with warning' do
      given_the_ruby_regexp(/[a-z]{6,8}+/)
      expect_js_regex_to_be(/[a-z]{6,8}/)
      expect_warning('possessive')
    end

    it 'makes group quantifiers none-possessive with warning' do
      given_the_ruby_regexp(/(?:a|b){6,8}+/)
      expect_js_regex_to_be(/(?:a|b){6,8}/)
      expect_warning('possessive')
    end
  end

  context 'when there are multiple quantifiers' do
    it 'drops adjacent/multiplicative fixes ({x}) with warning' do
      given_the_ruby_regexp(/a{4}{6}/)
      expect_js_regex_to_be(/a{4}/)
      expect_warning('adjacent quantifiers')
    end

    it 'drops adjacent/multiplicative ranges ({x,y}) with warning' do
      given_the_ruby_regexp(/a{2,4}{3,6}/)
      expect_js_regex_to_be(/a{2,4}/)
      expect_warning('adjacent quantifiers')
    end

    it 'drops mixed adjacent quantifiers' do
      given_the_ruby_regexp(/ab{2,3}*/)
      expect_js_regex_to_be(/ab{2,3}/)
      expect_warning('adjacent quantifiers')
    end

    it 'preserves distinct quantifiers' do
      given_the_ruby_regexp(/a{2}b{2}c{2,3}d{2,3}e+f+g?h?i*j*/)
      expect_js_regex_to_be(/a{2}b{2}c{2,3}d{2,3}e+f+g?h?i*j*/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string:         'aabbccdddefghi',
                                  with_results: %w(aabbccdddefghi))
    end
  end
end
