# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler lazy capture runs' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  ['(?:(a+)|(b+))', '(?:(b+)|(a+))'].product(%w[+? *?], ['\\1\\2', '\\2\\1']).each do |body, quantity, tail|
    it "retains ordered variable values for #{body}#{quantity}#{tail}" do
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..9).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      inputs += %w[abab abaab abbabab baaabab baabaab baabab abaabab baababa aabbaaabbb]
      ['', 'a', '\\z'].each do |ending|
        regexp = Regexp.new(body + quantity + tail + ending)
        example = SecondPassCorpus.example('lazy capture runs', regexp, inputs)
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

  it 'keeps continuation captures bound to their own copied branch' do
    regexp = /(?:(a+)|(b+))+?\1\2(c*)\3/
    inputs = %w[abab ababc ababcc ababcccc baababc aaabbaaabbcc]
    example = SecondPassCorpus.example('tail bindings', regexp, inputs)
    result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
    expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
  end

  it 'preserves enclosing captures across later lazy iterations and run splits' do
    [/((a+)|(b+))+?\2\3/, /((a+)|(b+))+?\2\3\1/,
     /(((a+)|(b+)))*?\4\3\2\1/].each do |regexp|
      inputs = (0..10).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('enclosing lazy runs', regexp, inputs)
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

  it 'requires disjoint greedy character runs and unique adjacent references' do
    [/(?:(a+)|(A+))+?\1\2/i, /(?:(ab+)|(b+))+?\1\2/,
     /(?:(a+?)|(b+))+?\1\2/, /(?:(a+)|(b+))+?\1\2\1/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      expression = compiler::Importer.call(tree)
      expect(compiler::LowerLazyRuns.call(expression)).to equal(expression)
    end
  end
end
