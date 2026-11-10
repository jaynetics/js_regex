# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler nullable choices' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  patterns = [/\A(?:(a*)|b)(?:c|\1)\z/, /\A(?:(a*)b)?c(?:d|\1)\z/,
              /(?:(a*)?b)\1/, /(?:(a*)??b)\1/, /a*(?:(a*)?b)\1/,
              /a*(?:(a*)?b)(?(1)c|a)\1?/, /(?:(a*)|(b*))\1?\2?/,
              /(?:(a*)?b|(c*))(?(1)\1|\2)/,
              /(a)?(?(1)(b*)|c)\2/, /(a)?(?(1)(b*))(?:\2|c)/,
              /(?:(a*)(b*))?\1\2/, /(?:(a*)(b*))??\1?\2?/,
              /(?:(?<x>a*)|b)(?<x>c*)?\k<x>/,
              /(?:(a*)?b)?(?(1)\1|c)/, /((a*)?)\1\2/,
              /(((a*)?))\1\2\3/, /((?:(a*)|b))\1\2?/]

  patterns.each do |regexp|
    it "preserves participation and choice order for #{regexp.inspect}" do
      if regexp == /(?:(?<x>a*)|b)(?<x>c*)?\k<x>/ && Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1.3')
        skip 'Ruby oracle predates the duplicate-name fix: https://bugs.ruby-lang.org/issues/18631'
      end
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) } + %w[cd bcd abcd]
      example = SecondPassCorpus.example(regexp.inspect, regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        actual = SecondPassCorpus.actual(@context, example, result)
        expected = SecondPassCorpus.expected(example)
        differences = inputs.each_index.select { |index| actual[index] != expected[index] }
        expect(differences.map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty
      end
    end
  end

  it 'does not copy tail captures whose references escape the rewritten region' do
    tree, = SecondPassCorpus.prepare(/((a*)?\2(b))\3/, JsRegex::Target::ES2009)
    original = compiler::Importer.call(tree)
    expect(compiler::LowerNullableChoices.call(original)).to equal(original)
    expect(compiler.call(tree).to_s).to eq('((a*)\\2(b))\\3')
  end
end
