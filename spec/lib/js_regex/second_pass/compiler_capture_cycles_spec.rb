# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler overlapping capture cycles' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  bodies = ['(?:(a+)|ab)', '(?:ab|(a+))', '(?:(ab+)|a)', '(?:a|(ab+))',
            '(?:([ab]+)|a)', '(?:a|([ab]+))', '(?:(a(?:b)?)|a)',
            '(?:(ab+)|a+)', '(?:(a+b)|a+)', '(?:(a+)|a(?:b)?)']
  bodies.product(%w[+ +? * *?]).each do |body, quantity|
    it "preserves branch and iteration order for #{body}#{quantity}" do
      inputs = (0..8).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      inputs += %w[abaab abbaabb abbabab baaabab baabaab baabab abaabab baababa aabbaaabbb]
      regexp = Regexp.new(body + quantity + '\\1')
      example = SecondPassCorpus.example('overlapping cycles', regexp, inputs)
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

  it 'retains the captured value while later assertions force backtracking' do
    [/\A(?:(ab+)|a)+\1\z/, /\A(?:(a+)|ab)+?\1b\z/].each do |regexp|
      inputs = (0..8).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('cycle tail', regexp, inputs)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2009, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end
end
