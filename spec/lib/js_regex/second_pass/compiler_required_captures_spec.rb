# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler required capture participation' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  [/(a)?\1/, /(a*)?\1/, /(a*)??\1/, /(a*(b*)?)\2/,
   /(a*(b*)??)\2/, /((a*)?\2(b))\3/, /((a)?)?\2/,
   /((a*)?)??\2/, /(a*)??(?=\1)\1/, /(a)?(?(1)\1|\1)/].each do |regexp|
    it "preserves captures and prefix backtracking for #{regexp.inspect}" do
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('required participation', regexp, inputs, groups: true)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example)),
          "#{regexp.inspect} on #{target}"
      end
    end
  end

  it 'keeps optional choices inside assertions, atomics, and repeated iterations' do
    [/(?=(a)??)\1/, /(?>(a)??)\1/, /(?:(a)?b)+\1/,
     /(a*)?(?:\1|b)/, /(a*)?(?!\1)/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      expression = compiler::Importer.call(tree)
      expect(compiler::RequireCaptures.call(expression)).to equal(expression)
      inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('scope boundary', regexp, inputs)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example)), regexp.inspect
    end
  end
end
