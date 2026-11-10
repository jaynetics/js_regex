# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler nested character loops' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  [/\A(?:(?:(a)|b)+|c)+\1\z/, /(?:(?:(a)|b)+|c)*\1?/,
   /(?:c|(?:b|(a))+)+\1/, /(?:(?:(a)|b)+|(c))+\1\2/,
   /(?:(?:(?:(a)|b)+|c)+|d)+\1/].each do |regexp|
    it "preserves matches and retained values for #{regexp.inspect}" do
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      inputs += %w[aa aba aca abca abcda abdcda bcd]
      example = SecondPassCorpus.example('nested loops', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
      end
    end
  end

  it 'does not flatten ambiguous or lazy iteration boundaries' do
    [/(?:(?:(a)|a)+|b)+\1/, /(?:(?:(ab)|c)+|d)+\1/,
     /(?:(?:(a)|b)+?|c)+\1/, /(?:(?:(a)|b)+|c)+?\1/,
     /(?:(?:(a)|b)*|c)+\1/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2009)
      expression = compiler::Importer.call(tree)
      expect(compiler::FlattenCharacterLoops.call(expression)).to equal(expression)
    end
  end
end
