# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::Base do
  describe '#warn_of_unsupported_feature' do
    it 'adds a warning with token class, subtype, data and index' do
      conv = described_class.new
      expr = expression_double({ type: 'bar', token: 'big', ts: 7 })
      allow(expr).to receive(:to_s).and_return('foo')
      allow(conv).to receive(:expression).and_return(expr)
      allow(conv).to receive(:warnings).and_return([])
      conv.send(:warn_of_unsupported_feature)
      expect(conv.send(:warnings).first).to eq(
        "Dropped unsupported big bar 'foo' at index 7"
      )
    end

    it 'takes an argument to override the description' do
      conv = described_class.new
      expr = expression_double({ type: 'bar', token: 'big', ts: 7 })
      allow(expr).to receive(:to_s).and_return('foo')
      allow(conv).to receive(:expression).and_return(expr)
      allow(conv).to receive(:warnings).and_return([])
      conv.send(:warn_of_unsupported_feature, 'fizz')
      expect(conv.send(:warnings).first).to eq(
        "Dropped unsupported fizz 'foo' at index 7"
      )
    end
  end

  describe '#convert' do
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
      it 'emulates possessiveness for zero-or-ones (?+)' do
        given_the_ruby_regexp(/a?+/)
        expect_js_regex_to_be(/(?=(a?))\1(?:)/)
        expect_no_warnings
      end

      it 'emulates possessiveness for zero-or-mores (*+)' do
        given_the_ruby_regexp(/a*+/)
        expect_js_regex_to_be(/(?=(a*))\1(?:)/)
        expect_no_warnings
      end

      it 'emulates possessiveness for one-or-mores (++)' do
        given_the_ruby_regexp(/a++/)
        expect_js_regex_to_be(/(?=(a+))\1(?:)/)
        expect_no_warnings
      end

      it 'emulates possessiveness for fixes ({x}+)' do
        given_the_ruby_regexp(/a{4}+/)
        expect_js_regex_to_be(/(?=(a{4}))\1(?:)/)
        expect_no_warnings
      end

      it 'emulates possessiveness for ranges ({x,y}+)' do
        given_the_ruby_regexp(/a{6,8}+/)
        expect_js_regex_to_be(/(?=(a{6,8}))\1(?:)/)
        expect_no_warnings
      end

      it 'emulates possessiveness for set quantifiers' do
        given_the_ruby_regexp(/[a-z]{6,8}+/)
        expect_js_regex_to_be(/(?=([a-z]{6,8}))\1(?:)/)
        expect_no_warnings
      end

      it 'emulates possessiveness for group quantifiers' do
        given_the_ruby_regexp(/(?:a|b){6,8}+/)
        expect_js_regex_to_be(/(?=((?:a|b){6,8}))\1(?:)/)
        expect_no_warnings
      end

      it 'takes into account preceding active groups for the backreference' do
        given_the_ruby_regexp(/(a)(b)(c)_d++/)
        expect_js_regex_to_be(/(a)(b)(c)_(?=(d+))\4(?:)/)
        expect_no_warnings
      end

      it 'isnt confused by preceding passive groups' do
        given_the_ruby_regexp(/(?:c)_a++/)
        expect_js_regex_to_be(/(?:c)_(?=(a+))\1(?:)/)
        expect_no_warnings
      end

      it 'isnt confused by preceding lookahead groups' do
        given_the_ruby_regexp(/(?=c)_a++/)
        expect_js_regex_to_be(/(?=c)_(?=(a+))\1(?:)/)
        expect_no_warnings
      end

      it 'isnt confused by preceding negative lookahead groups' do
        given_the_ruby_regexp(/(?!=x)_a++/)
        expect_js_regex_to_be(/(?!=x)_(?=(a+))\1(?:)/)
        expect_no_warnings
      end
    end

    context 'when there are multiple quantifiers' do
      it 'drops adjacent/multiplicative fixes ({x}) without warning' do
        given_the_ruby_regexp(/a{4}{6}/)
        expect_js_regex_to_be(/a{6}/)
        expect_no_warnings
      end

      it 'drops adjacent/multiplicative ranges ({x,y}) without warning' do
        given_the_ruby_regexp(/a{2,4}{3,6}/)
        expect_js_regex_to_be(/a{3,6}/)
        expect_no_warnings
      end

      it 'drops mixed adjacent quantifiers without warning' do
        given_the_ruby_regexp(/ab{2,3}*/)
        expect_js_regex_to_be(/ab*/)
        expect_no_warnings
      end

      it 'drops multiple adjacent quantifiers without warning' do
        given_the_ruby_regexp(/ab{2}{3}{4}{5}/)
        expect_js_regex_to_be(/ab{5}/)
        expect_no_warnings
      end

      it 'preserves distinct quantifiers' do
        given_the_ruby_regexp(/a{2}b{2}c{2,3}d{2,3}e+f+g?h?i*j*/)
        expect_js_regex_to_be(/a{2}b{2}c{2,3}d{2,3}e+f+g?h?i*j*/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string:         'aabbccdddefghi',
                                    with_results: %w[aabbccdddefghi])
      end
    end

    context 'when quantifiers follow dropped elements' do
      it 'drops the quantifiers as well' do
        given_the_ruby_regexp(/a\e{2,3}b[😁]++c/)
        expect_js_regex_to_be(/abc/)
      end
    end
  end
end
