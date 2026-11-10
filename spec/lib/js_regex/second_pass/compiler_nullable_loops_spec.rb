# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler nullable unbounded loops' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  patterns = [/\A(a*)*\1\z/, /\A(a*)+\1\z/, /\A(a*)*(?!\1)a\z/,
              /\A(a*?)*\1a/, /\A(a*?b*)*\1/, /\A(a*b*?)*\1/,
              /\A(a*b*?)*\1\z/, /\A(a*?)*(?(1)b|a)\1?/,
              /\A(a*)+(?(1)b|a)\1?/, /(a*)*\1(b)\2/,
              /(?<x>a*)*\k<x>/, /(a*)*\1?(b*)*\2/,
              /\A(?:(a*)|b)+\1\z/, /(?:(a*)|b)+\1/,
              /(?:(a*)|b)+(?(1)c|a)/, /(?:(a*)|b)*(?!\1)a/,
              /(?:b|(a*))+\1/, /(?:b|(a*))*\1a/,
              /(?:(a*)|b|c)+\1/, /(?:b|(a*)|c)+\1/,
              /\A(?:(a*)|b)+\1(c+)\2\z/,
              /\A((a)?)+\1\2\z/, /((a)?)*\2\1/,
              /((ab+)?)+\1\2/, /((a)?)*(?(2)b|a)\1/]

  patterns.each do |regexp|
    it "preserves final empty values and backtracking for #{regexp.inspect}" do
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('nullable ending', regexp, inputs)
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

  it 'does not discard the empty-update history of an empty-first alternative' do
    [/(?:(a*?)|b)+\1a/, /(?:b|(a*?))+\1a/, /(?:(|a)|b)+\1a/,
     /(?:(a*)|b|c)+(?(1)b|a)\1?/, /(?:(a*)|b)+\1b(?=b{3}$|$)/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      expect { compiler.call(tree) }.to raise_error(compiler::Unsupported)
    end
  end

  it 'collapses lazy repetition of greedy runs while preserving final empty capture arrays' do
    [/(a*)+?\1/, /(a*)*?\1/, /([ab]*)*?\1/, /((?:a)*)+?\1/,
     /((a*)+?\2)\1/, /((a*)+?\2)a/,
     /((a*)*?\2)\1b/, /((?:ab)*)+?\1/,
     /((?:a|ab)*)+?\1/, /((?:a|b)*)*?\1/].each do |regexp|
      inputs = (0..8).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('lazy nullable run', regexp, inputs, groups: true)
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

  it 'keeps its progress captures inside the generated loop and assertion scopes' do
    tree, = SecondPassCorpus.prepare(/(a*)*\1/, JsRegex::Target::ES2009)
    lowered = compiler::LowerNullableLoops.call(compiler::Importer.call(tree))
    loops = []
    compiler.walk(lowered) { |part| loops << part if part.kind == :native_repeat }
    expect(loops.length).to eq(1)
    body = loops.first.children.first
    expect(body.children.map(&:kind)).to eq([:negative_lookahead, :lookahead, :capture, :negative_lookahead])
    expect(body.children[2].nonempty).to eq(true)
    expect(body.children[1].children.first.reference).to equal(body.children.last.children.first.reference)
    expect(compiler::Emitter.call(compiler::ResolveReferences.call(lowered)).to_s).not_to be_empty
  end

  it 'preserves repeated greedy stars through longer continuations and higher minimum counts' do
    bodies = ['a', '[ab]', '(?:ab)', '(?:a|ab)', '(?:ab|a)', '(?:ab?)', '(?:a+?b?)']
    tails = ['a', 'ab', 'b*', '(?:a|ba)', '(?=a)a', '(?!ab)a', '(b*)\\2', '\\z']
    inputs = (0..8).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    quantities = ['*?', '+?', '*', '+', '{2,}', '{3,}', '{2,}?', '{3,}?']
    bodies.product(quantities, ['', '?', '??'], tails).each do |body, quantity, reference_quantity, tail|
      regexp = Regexp.new('(' + body + '*)' + quantity + '\\1' + reference_quantity + tail)
      example = SecondPassCorpus.example('lazy nullable continuation', regexp, inputs, groups: true)
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

  it 'preserves lazy runs containing directly nested quantifiers' do
    # Older Ruby engines rewrite (?:a+?)* to (?:a+?)? while compiling a Regexp,
    # changing the source's preferred endpoint before SecondPass is involved.
    if Regexp.new('((?:a+?)*)').match('aa')[0] != 'aa'
      skip 'Ruby oracle rewrites directly nested quantifiers before matching'
    end
    regexp = Regexp.new('((?:a+?)*)*?\\1a')
    inputs = (0..8).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    example = SecondPassCorpus.example('nested quantifiers', regexp, inputs, groups: true)
    result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2009, pass: compiler)
    expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
  end

  it 'simplifies independent lazy runs and preserves enclosing capture values' do
    [/\A(a*)+?\1(b*)+?\2\z/, /\A(a*)*?\1?(b*)*?\2?\z/,
     /((a*)+?\2a)\1/, /((a*)*?\2?a)\1/,
     /\A(a*){20,}\1a\z/, /\A(a*){20,}?\1?a\z/].each do |regexp|
      inputs = (0..8).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('enclosing lazy runs', regexp, inputs, groups: true)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'keeps capture-dependent continuations and empty-body iterations outside the star simplification' do
    [/(a*)+\1(?!\1)a/, /(a*){2,}\1\1/, /((?:a?b?)*)+\1/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2009)
      expression = compiler::Importer.call(tree)
      expect(compiler::SimplifyLoops.call(expression)).to equal(expression)
    end
  end

  it 'preserves all capture arrays when nested captures cover the same repeated run' do
    ['*', '+', '*?', '+?', '{2,}', '{2,}?'].product(['\\1', '\\2', '\\1?', '\\2?']).each do |quantity, reference|
      regexp = Regexp.new('((a*))' + quantity + reference + '(b*)\\3a?')
      inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('nested equal captures', regexp, inputs, groups: true)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2009, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example)), regexp.inspect
    end
  end

  it 'updates nested captures together when they cover the entire nullable iteration' do
    bodies = ['a*', 'a*?', '|a', 'a|', 'a*b*', 'a*?b*?']
    tails = ['\\1a', '\\2', '\\1\\2a', '(?!\\2)a', '(?(2)b|a)']
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    bodies.product(['*', '+', '*?', '+?'], tails, [false, true]).each do |body, quantity, tail, anchored|
      source = '((' + body + '))' + quantity + tail
      regexp = Regexp.new(anchored ? '\\A' + source + '\\z' : source)
      example = SecondPassCorpus.example('nullable capture aliases', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'preserves alias participation through passive groups, assertions, and named references' do
    patterns = [/((?:(a*?)))*\1\2a/, /(((a*b*)))*?\3\2\1a/,
                /(?<outer>(?<inner>a*?))*?\k<outer>\k<inner>a/i,
                /(?=(((a*b*))*?\2\3a))\1/, /(?!((a*?))*\1\2a)b+/,
                /((😋*?))*?\1\2a/]
    inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    inputs += %w[Aa aAaA aaAAa 😋a 😋😋a 😋a😋a 😋😋aa]
    patterns.each do |regexp|
      example = SecondPassCorpus.example('scoped capture aliases', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'does not treat captures with independent updates as aliases' do
    [/((a*?)?)*?\1\2a/, /((a*?)b*)*?\1\2a/, /(?:((a*?))|b)*\1\2a/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      children = tree.children
      expect { compiler.call(tree) }.to raise_error(compiler::Unsupported), regexp.inspect
      expect(tree.children).to equal(children)
    end
  end

  it 'preserves whole-iteration values when nested regular captures are never read' do
    inputs = (0..5).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    ['a*(b*)?', 'a*(b*)??', 'a*(a*)?', '(a*?)(b*?)', '(?:|a(b*))'].product(
      ['*', '+', '*?', '+?'], ['\\1a', '(?!\\1)a', '(?(1)b|a)\\1?']
    ).each do |body, quantity, tail|
      regexp = Regexp.new('(' + body + ')' + quantity + tail)
      example = SecondPassCorpus.example('unobserved nested captures', regexp, inputs)
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
end
