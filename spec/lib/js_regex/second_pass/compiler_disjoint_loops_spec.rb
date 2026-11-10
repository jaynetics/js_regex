# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler disjoint capture loops' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  ['(?:(a)|b)', '(?:b|(a))', '(?:(a+)|b)', '(?:(ab+)|c)'].product(%w[+ +? * *?]).each do |body, quantity|
    it "preserves ordered matching for #{body}#{quantity}" do
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      ['\\1', '\\1?', '(?(1)c|a)'].each do |suffix|
        regexp = Regexp.new(body + quantity + suffix)
        example = SecondPassCorpus.example('disjoint loop', regexp, inputs)
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
  end

  it 'does not assume disjointness for case variants, overlapping prefixes, or nullable updates' do
    [/(?:(a)|A)+\1?/i, /(?:(s)|ſ)+\1?/i, /(?:(a)|ab)+\1?/, /(?:(a*)|b)+\1/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2009)
      expression = compiler::Importer.call(tree)
      expect(compiler::PreserveCaptureCycles.call(expression)).to equal(expression)
    end
  end

  it 'does not reorder a variable skipping iteration before a later capture update' do
    regexp = /(?:(a)|b+)+?(?(1)c|b)/
    tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
    expression = compiler::Importer.call(tree)
    expect(compiler::PreserveCaptureCycles.call(expression)).to equal(expression)
    example = SecondPassCorpus.example('ordered variable skips', regexp, %w[bbac abbab bbbac])
    result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
    expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))

    [/(?:(a)|(b+)){2,}?(?(1)b|a)/, /(?:(a+)|(b+)){2,}?(?(1)b|a)/].each do |pattern|
      inputs = (0..8).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('participation before a lazy suffix', pattern, inputs)
      result = SecondPassCorpus.convert(pattern, target: JsRegex::Target::ES2018, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'handles character classes and astral captures on every target' do
    examples = [
      SecondPassCorpus.example('astral retention', /\A(?:(😋)|b)+\1\z/, ['', 'b', '😋b😋', '😋bb😋', '😋b']),
      SecondPassCorpus.example('class retention', /\A(?:([ab]+)|c)+\1\z/, ['', 'c', 'abccab', 'bcbb', 'acb', 'abab']),
    ]
    examples.each do |example|
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(example.regexp, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
      end
    end
  end

  it 'preserves greedy order with variable skips that cannot expose capture starts' do
    bodies = ['(?:(a+)|b+)', '(?:b+|(a+))', '(?:(ab+)|c+)',
              '(?:(a+)|b+?)', '(?:(a+)|b{1,3})', '(?:(a+)|b|bb)',
              '((a+)|b+)', '(?:(a+)|(b+))']
    inputs = (0..7).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
    bodies.product(['*', '+', '{2,}'], ['\\1?', '(?(1)(?=bb)|)', '(?(1)c|b)\\1?']).each do |body, quantity, tail|
      # For an enclosing capture, also observe both the retained inner value
      # and the last original iteration, including variable skipping iterations.
      tail = tail.gsub('1', '2') + '\\1?' if body.start_with?('((')
      regexp = Regexp.new(body + quantity + tail)
      example = SecondPassCorpus.example('greedy variable skips', regexp, inputs)
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

  it 'does not expose capture starts hidden inside variable skipping iterations' do
    [/(?:(a)|ba?)+(?(1)(?=bb)|)/, /(?:(a+)|ba?)+\1?/,
     /(?:(a)|bA?)+(?(1)(?=bb)|)/i].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      expression = compiler::Importer.call(tree)
      expect(compiler::PreserveCaptureCycles.call(expression)).to equal(expression)
    end
  end
end
