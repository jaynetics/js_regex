# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler empty-first loop ordering' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  [/(?:|a)*a/, /(?:|a)?a/, /(?:|ab|a){3}aba/, /(?:a*?b*?)+ab/,
   /((?:|a)*)+?\1?/, /((?:a*?b*?)*)+?\1?/,
   /((?:|ab|a){3,5})\1a/, /((?:a*?b*?){2,}?)\1ab/,
   /((?:|a){0,3})(b*)\1\2/, /(b*?)?/, /(b*?)?b/,
   /((?:|a))?a/, /((a*?))?b/, /(a*?(b*?)?)\1/,
   /(?<x>a*(?<y>b*?)?)(?<x>c)?\k<x>/].each do |regexp|
    it "preserves first and global results for #{regexp.inspect}" do
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('empty-first loop', regexp, inputs, groups: true)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'preserves capture values and bounds across empty-first body shapes' do
    bodies = ['|a', '|ab|a', '|a|ab', 'a*?b*?', 'a??b??', '(?:|a)b*?', 'a*?(?:|b)']
    quantities = ['?', '??', '{1}', '*', '+', '{2}', '{0,3}', '{2,3}', '{3,5}', '{2,}', '*?', '+?', '{2}?', '{2,3}?', '{2,}?']
    tails = ['\\1', '\\1a', '\\1ab', '\\1?', '(?!\\1)a', '(?(1)b|a)\\1?']
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    bodies.product(quantities, tails, [false, true]).each do |body, quantity, tail, anchored|
      source = '((?:' + body + ')' + quantity + ')' + tail
      regexp = Regexp.new(anchored ? '\\A' + source + '\\z' : source)
      example = SecondPassCorpus.example('empty-first bounds', regexp, inputs, groups: true)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
      [false, true].each do |global|
        expected = SecondPassCorpus.expected(example, global: global)
        actual = SecondPassCorpus.actual(@context, example, result, global: global)
        differences = inputs.each_index.select { |index| actual[index] != expected[index] }
        expect(differences.take(5).map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty,
          "#{regexp.inspect}, global: #{global}"
      end
    end
  end

  it 'normalizes inner loops before lowering lazy nullable capture repetitions' do
    ['(?:|a)*', '(?:a*?b*?)*', '(?:(?:|a){2,3})*'].product(['*?', '+?'], ['\\1a', '\\1ab', '(?!\\1)a']).each do |body, quantity, tail|
      regexp = Regexp.new('(' + body + ')' + quantity + tail)
      inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('nested empty loops', regexp, inputs)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
      [false, true].each do |global|
        expect(SecondPassCorpus.actual(@context, example, result, global: global))
          .to eq(SecondPassCorpus.expected(example, global: global)), regexp.inspect
      end
    end
  end

  it 'preserves case-insensitive values and Unicode offsets' do
    regexp = /((?:|aB){3})\1a/i
    example = SecondPassCorpus.example('empty loop casing', regexp, ['a', 'ABaBa', '😋ABaBa', 'aBABabABA'], groups: true)
    result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
    [false, true].each do |global|
      expect(SecondPassCorpus.actual(@context, example, result, global: global))
        .to eq(SecondPassCorpus.expected(example, global: global))
    end
  end

  it 'does not normalize loops whose empty-first bodies read captures' do
    tree, = SecondPassCorpus.prepare(/(?=(a))(?:(?:|\1))*\1/, JsRegex::Target::ES2018)
    children = tree.children
    expect { compiler.call(tree) }.to raise_error(compiler::Unsupported, /empty-first ordering/)
    expect(tree.children).to equal(children)
  end
end
