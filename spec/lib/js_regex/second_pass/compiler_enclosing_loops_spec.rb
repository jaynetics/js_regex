# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler enclosing capture loops' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  ['((a)|b)', '((a+)|b)', '(b|(a+))'].product(%w[+ +? * *? {2,} {3,}?]).each do |body, quantity|
    it "retains both capture values for #{body}#{quantity}" do
      inputs = (0..8).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      ['\\2\\1', '\\1\\2', '\\2?(?(1)b|a)', '(?(2)a|b)\\1'].each do |tail|
        regexp = Regexp.new(body + quantity + tail)
        example = SecondPassCorpus.example('enclosing capture', regexp, inputs)
        JsRegex::Target::SUPPORTED.each do |target|
          result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
          actual = SecondPassCorpus.actual(@context, example, result)
          expected = SecondPassCorpus.expected(example)
          differences = inputs.each_index.select { |index| actual[index] != expected[index] }
          expect(differences.take(10).map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty,
            "#{regexp.inspect} on #{target}"
        end
      end
    end
  end

  it 'retains nested wrappers and other captures in skipping branches' do
    [/(((a)|b))+\3\2\1/, /((a)|(b)|c|d)+\3/,
     /((a)|(b)|c|d)+(?:e|\3)\1/, /\A((a)|b)+\2?\z/].each do |regexp|
      inputs = (0..6).flat_map { |length| %w[a b c d].repeated_permutation(length).map(&:join) }
      inputs += %w[ce be bce ace abea]
      example = SecondPassCorpus.example('nested enclosing captures', regexp, inputs)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example)), regexp.inspect
    end
  end

  it 'retains final enclosing values separately from constant inner state' do
    inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
    ['(a)?b', '(a)??b', '(ab)?c', 'a(b)?'].product(
      ['*', '+?', '{2,}', '{3,}?'], ['\\1\\2', '\\2\\1', '(?(2)a|b)\\1']
    ).each do |body, quantity, tail|
      regexp = Regexp.new('(' + body + ')' + quantity + tail)
      example = SecondPassCorpus.example('enclosing state values', regexp, inputs)
      expected = [false, true].to_h { |global| [global, SecondPassCorpus.expected(example, global: global)] }
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(expected[global]), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end
end
