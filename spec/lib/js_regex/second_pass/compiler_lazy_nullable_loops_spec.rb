# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler lazy nullable loops' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  [/\A(a*?)*?\1\z/, /\A(a*?)+?\1a\z/, /(|a)*?\1a/,
   /(|ab)+?\1ab/, /(a??)*?(?!\1)a/, /(a*?b*?)*?\1a/,
   /(?:x|y)(a*?)+?(?(1)b|a)\1?/, /(a*?)*?\1(b*)\2/,
   /((a*?)*?\2a)\1/, /(b)((a*?)*?\3a)\1\2/,
   /(?<n>a*?)*?\k<n>a/, /(😋*?)*?\1a/,
   /\A(a*)*?\1a\z/, /(a*b*)+?\1ab/, /(a?)*?\1a/,
   /(a|)*?\1a/, /(ab|a|)+?\1ab/].each do |regexp|
    it "preserves ordered empty updates for #{regexp.inspect}" do
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      inputs += %w[xaab yaabb baabbaa 😋a 😋😋a 😋a😋a 😋😋aa]
      example = SecondPassCorpus.example('lazy empty updates', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
      end
    end
  end

  it 'preserves first and global matches through varied continuations' do
    bodies = ['a*?', '|a', 'a??', '(?:|ab)', 'a*?b*?', '(?:|a|ab)', '(?:|ab|a)', 'a??b??',
              'a*', 'a?', 'a*b*', '(?:ab)*', 'a?b?', 'a|', 'ab|a|', 'a+?|', 'a|ab|']
    tails = ['\\1', '\\1a', '\\1ab', '\\1?', '\\1??', '\\1\\1', '(?!\\1)a',
             '(?(1)b|a)', '(?(1)b|a)\\1?', '(b*)\\2\\1']
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    inputs += %w[abababab aaaabbbb aabaabaab babaabaaa]
    bodies.product(['*?', '+?'], tails, [false, true]).each do |body, quantity, tail, anchored|
      source = '(' + body + ')' + quantity + tail
      regexp = Regexp.new(anchored ? '\\A' + source + '\\z' : source)
      example = SecondPassCorpus.example('lazy empty continuation', regexp, inputs)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
      [false, true].each do |global|
        expected = SecondPassCorpus.expected(example, global: global)
        actual = SecondPassCorpus.actual(@context, example, result, global: global)
        differences = inputs.each_index.select { |index| expected[index] != actual[index] }
        expect(differences.take(5).map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty,
          "#{regexp.inspect}, global: #{global}"
      end
    end
  end

  it 'preserves case-insensitive values and matching after an astral prefix' do
    regexp = /(a*?)*?\1b/i
    example = SecondPassCorpus.example('lazy empty casing', regexp, ['aAb', 'AAbaab', '😋aAb', 'bB', '😋'])
    result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
    [false, true].each do |global|
      expect(SecondPassCorpus.actual(@context, example, result, global: global))
        .to eq(SecondPassCorpus.expected(example, global: global))
    end
  end

  it 'keeps continuation filters conservative around captures, choices, and assertions' do
    patterns = [/(c)(a*?)*?\2\1b/, /(a*?)*?\1(?=(b+))\2/,
                /(a*?)*?\1(?!b)c/, /(a*?)*?\1(?:b|c)/,
                /(a*?)*?\1(?>b|bc)c/,
                /(?<v>b)(?<v>c)(?<x>a*?)*?\k<x>\k<v>/]
    inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
    patterns.each do |regexp|
      example = SecondPassCorpus.example('tail filter', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'rejects long impossible tails before exploring equivalent loop partitions' do
    [/\A(a*?)*?\1a\z/, /\A(a*?b*?)*?\1a\z/,
     /\A(a*b*)*?\1a\z/, /\A(?:(a+)|(b+))+?\1\2\z/].each do |regexp|
      inputs = [32, 64, 256].map { |length| 'a' * length + 'b' * length + 'c' }
      example = SecondPassCorpus.example('impossible anchored tail', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq([nil, nil, nil]), regexp.inspect
      end
    end
  end

  it 'preserves grouping around regular source fragments in continuation filters' do
    tail = compiler::Expression.new(:sequence, ['x', compiler::Expression.new(:group, ['a|b']), 'c', '$'])
    filter = compiler::TailFilter.new(compiler::Analysis.new(tail)).call(tail)
    result = SecondPassCorpus::Result.new(source: compiler::Emitter.call(filter).to_s, options: '', warnings: [])
    example = SecondPassCorpus.example('grouped filter fragment', /(?=.*x(?:a|b)c$)/, %w[xac xbc zxbc xc xbcd])
    expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
  end

  it 'leaves general nullable histories unsupported' do
    [/(?:(a*?)|b)*?\1a/, /(a*?\1)*?\1a/, /((a*b*)*?\2)\1b/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      children = tree.children
      expect { compiler.call(tree) }.to raise_error(compiler::Unsupported), regexp.inspect
      expect(tree.children).to equal(children)
    end
  end

  it 'tries the empty update between the correct consuming paths in mixed bodies' do
    bodies = ['a*?b*', 'a*b*?', 'a?|b', 'a*?|b*', 'a??b?', 'a?b??', 'a*?b*a*?', 'a*?b*|a']
    inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    bodies.product(['*?', '+?', '{2,}?'], ['\\1', '\\1a', '(?!\\1)a', '(?(1)b|a)\\1?'], [false, true]).each do |body, quantity, tail, anchored|
      source = '(' + body + ')' + quantity + tail
      regexp = Regexp.new(anchored ? '\\A' + source + '\\z' : source)
      example = SecondPassCorpus.example('mixed empty paths', regexp, inputs)
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

  it 'preserves mixed empty-path order for alias captures, case folding, and astral input' do
    patterns = [/((a*?b*))*?\1\2a/i, /((a?|b)){2,}?\1\2a/,
                /(?<x>😋*?b*)*?\k<x>a/, /(?=((a*?b*)*?\2a))\1/]
    inputs = (0..5).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    inputs += %w[Aa aBAa bAAba 😋a 😋ba 😋b😋a 😋😋bba 😋😋bb]
    patterns.each do |regexp|
      example = SecondPassCorpus.example('mixed capture aliases', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

end
