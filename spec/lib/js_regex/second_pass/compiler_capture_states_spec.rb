# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler capture-state loops' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  patterns = [/(?:(a)|(b))+\1\2/, /(?:(a)|(b))+?\1\2/, /(?:(a)|(b))*?\2\1/,
              /(?:(aa)|(a))+?\1\2/, /(?:(a)|ab\1)+/, /(?:b\1|(a))+/, /(?:(a)|\1)+/,
              /(?:(a)|(?(1)ab|c))+\1/, /(?:(a)|(?(1)b|c))+\1/,
              /(?:(a)|ab)+?(?(1)c|a)/, /(?:(a)|ab)*?(?(1)c|a)/,
              /(?:(a+)|ab)+?(?(1)c|a)/, /(?:([ab]+)|b)+?(?(1)c|a)/,
              /(?:(ab+)|ab)+?(?(1)c|a)/, /(?:(a)?b)+\1/,
              /(?:(a)|ab)+\1/, /(?:(a)|ab)+?\1?/,
              /(?:(?<x>a)|(?<x>aa))+\k<x>a/, /(?:(a{0})?b)+\1/,
              /(a?(?(1)|b?))*(?(1)a|b)/, /(a?(?(1)|b?))*?(?(1)a|b)/,
              /\A((?(1)b|a))+\z/, /\A((?(1)b|a)?)+\z/]

  patterns.each do |regexp|
    it "preserves ordered matching for #{regexp.inspect}" do
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..7).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      inputs += %w[aaaaaa aaaaaaa aaaaaaaa aabbab babaab aabc aaba ababa]
      example = SecondPassCorpus.example(regexp.inspect, regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        actual = SecondPassCorpus.actual(@context, example, result)
        expected = SecondPassCorpus.expected(example)
        differences = inputs.each_index.select { |index| actual[index] != expected[index] }
        expect(differences.map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty,
          regexp.inspect
      end
    end
  end

  it 'does not replace variable capture values with participation alone' do
    [/(?:(a+)|ab)+?(?:c|\1)/, /(?:(a+)|(b+))+?\1\2/, /(?:(a)|(?(1)b))+\1/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2009)
      expression = compiler::Importer.call(tree)
      expect(compiler::LowerCaptureStates.call(expression)).to equal(expression)
    end
  end

  it 'uses literal substitutions with the original case-insensitive options' do
    regexp = /(?:(a)|A)+\1/i
    inputs = (0..6).flat_map { |length| %w[a A b].repeated_permutation(length).map(&:join) }
    example = SecondPassCorpus.example('folded constant', regexp, inputs)
    result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
    expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
  end

  it 'preserves empty-iteration priority when only scalar participation is observed' do
    bodies = ['(a*)', '(a*?)', '(a|)', '(|a)', '()', '(a?)', '(a??)', '(a{0,3})', '(a{0,3}?)']
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    tails = ['(?(1)b|a)', '(?(1)a|b)', '(?(1)(?=a)|b)', '(?(1)b)', '(?(1)(b)|(a))\\2?\\3?']
    bodies.product(['*', '+', '*?', '+?'], tails).each do |body, quantity, tail|
      regexp = Regexp.new(body + quantity + tail)
      example = SecondPassCorpus.example('nullable participation', regexp, inputs)
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

  it 'resolves constant empty values without native empty-iteration clearing' do
    [/()*\1/, /()+?\1/, /(a{0})*?\1a/, /\A(){1,}\1\z/].each do |regexp|
      example = SecondPassCorpus.example('constant empty value', regexp, ['', 'a', 'aa', 'b', 'ba'])
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
      end
    end
  end
end
