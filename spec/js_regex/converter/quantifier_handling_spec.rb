# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter do
  describe 'quantifier handling' do
    context 'when quantifiers are possessive' do
      it 'makes zero-or-ones (?+) none-possessive with warning' do
        given_the_ruby_regexp(/a?+/)
        expect_js_regex_to_be(/a?/)
        expect_warning
      end

      it 'makes zero-or-mores (*+) none-possessive with warning' do
        given_the_ruby_regexp(/a*+/)
        expect_js_regex_to_be(/a*/)
        expect_warning
      end

      it 'makes one-or-mores (++) none-possessive with warning' do
        given_the_ruby_regexp(/a++/)
        expect_js_regex_to_be(/a+/)
        expect_warning
      end

      it 'makes fixes ({x}+) none-possessive with warning' do
        given_the_ruby_regexp(/a{4}+/)
        expect_js_regex_to_be(/a{4}/)
        expect_warning
      end

      it 'makes ranges ({x,y}+) none-possessive with warning' do
        given_the_ruby_regexp(/a{6,8}+/)
        expect_js_regex_to_be(/a{6,8}/)
        expect_warning
      end

      it 'makes set quantifiers none-possessive with warning' do
        given_the_ruby_regexp(/[a-z]{6,8}+/)
        expect_js_regex_to_be(/[a-z]{6,8}/)
        expect_warning
      end

      it 'makes group quantifiers none-possessive with warning' do
        given_the_ruby_regexp(/(?:a|b){6,8}+/)
        expect_js_regex_to_be(/(?:a|b){6,8}/)
        expect_warning
      end
    end

    context 'when quantifiers are escaped' do
      it 'treats zero-or-ones (?) as literal' do
        given_the_ruby_regexp(/\?/)
        expect_js_regex_to_be(/\?/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '-?-', with_results: %w(?))
      end

      it 'treats zero-or-mores (*) as literal' do
        given_the_ruby_regexp(/\*/)
        expect_js_regex_to_be(/\*/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '-*-', with_results: %w(*))
      end

      it 'treats one-or-mores (+) as literal' do
        given_the_ruby_regexp(/\+/)
        expect_js_regex_to_be(/\+/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '-+-', with_results: %w(+))
      end

      it 'treats fixes ({x}) as literal' do
        given_the_ruby_regexp(/\{4\}/)
        expect_js_regex_to_be(/\{4\}/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '-{4}-', with_results: %w({4}))
      end

      it 'treats ranges ({x,y}) as literal' do
        given_the_ruby_regexp(/\{4,6\}/)
        expect_js_regex_to_be(/\{4,6\}/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '-{4,6}-', with_results: %w({4,6}))
      end
    end

    context 'when there are multiple interval quantifiers' do
      it 'drops adjacent/multiplicative fixes ({x}) with warning' do
        given_the_ruby_regexp(/a{4}{6}/)
        expect_js_regex_to_be(/a{4}/)
        expect_warning
      end

      it 'preserves distinct fixes ({x})' do
        given_the_ruby_regexp(/a{2}b{3}/)
        expect_js_regex_to_be(/a{2}b{3}/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'aabbb', with_results: %w(aabbb))
      end

      it 'drops adjacent/multiplicative ranges ({x,y}) with warning' do
        given_the_ruby_regexp(/a{2,4}{3,6}/)
        expect_js_regex_to_be(/a{2,4}/)
        expect_warning
      end

      it 'preserves distinct ranges' do
        given_the_ruby_regexp(/a{2,4}b{3,6}/)
        expect_js_regex_to_be(/a{2,4}b{3,6}/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'aabbb', with_results: %w(aabbb))
      end
    end
  end
end
