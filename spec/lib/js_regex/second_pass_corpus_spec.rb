# frozen_string_literal: true

require_relative '../../support/second_pass_corpus'

describe 'SecondPass rewrite compatibility corpus' do
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  SecondPassCorpus::CASES.each do |example|
    example.targets.each do |target|
      it "preserves #{example.name} on #{target}" do
        result = SecondPassCorpus.convert(example.regexp, target: target)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
      end

      it "uses the production conversion boundary for #{example.name} on #{target}" do
        result = SecondPassCorpus.convert(example.regexp, target: target)
        production = JsRegex.new(example.regexp, target: target)
        expect([result.source, result.options, result.warnings])
          .to eq([production.source, production.options, production.warnings])
      end
    end
  end

  it 'accepts an independent implementation without changing the production pass' do
    pass = Class.new do
      def self.call(tree)
        tree.update(children: ['replacement'])
      end
    end
    result = SecondPassCorpus.convert(/original/, target: JsRegex::Target::ES2009, pass: pass)
    expect(result.source).to eq('replacement')
    expect(JsRegex.new(/original/).source).to eq('original')
  end

  it 'compares global captures and positions independently for each input' do
    example = SecondPassCorpus.example('global captures', /(a)?b/, %w[abb ab bbb c], groups: true)
    result = SecondPassCorpus.convert(example.regexp, target: JsRegex::Target::ES2018)
    expect(SecondPassCorpus.actual(@context, example, result, global: true))
      .to eq(SecondPassCorpus.expected(example, global: true))
  end

  it 'advances empty global matches by Unicode characters when u is enabled' do
    example = SecondPassCorpus.example('empty global matches', /()/, ['😋a', 'a😋', ''], groups: true)
    result = SecondPassCorpus::Result.new(source: '()', options: 'u', warnings: [])
    expect(SecondPassCorpus.actual(@context, example, result, global: true))
      .to eq(SecondPassCorpus.expected(example, global: true))
    expect(SecondPassCorpus.expected(example, global: true).first.map(&:first)).to eq([0, 2, 3])
  end
end
