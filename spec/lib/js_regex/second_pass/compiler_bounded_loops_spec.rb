# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler bounded capture loops' do
  let(:compiler) { JsRegex::SecondPass::Compiler }

  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  patterns = [/(?:(a)|b){2}\1/, /(?:(a)|b){1,3}\1/,
              /(?:(a)|b){0,3}\1/, /(?:(a)?b){1,3}\1/,
              /(?:(a+)|b){1,3}\1/,
              /(?:(ab+)|a){1,3}\1/, /(?:(a)|(b)){1,3}\1\2/,
              /((a)|b){1,3}\2\1/,
              /(?:(a)|b\1){1,3}/, /(?:(a)|(?(1)b|c)){1,3}\1/,
              /(?:\1b|(a)){1,3}/, /(?:(?=(a))a|b){1,3}\1/,
              /(?:(?!(a))b|a){1,3}\1/,
              /(?:(?:(a)|b){1,2}|c){1,2}\1/,
              /(?<x>a)(?:(?<x>b)|c){1,3}\k<x>/,
              /(a)?(?:\g<1>|b){1,2}\1/,
              /(a)?(?:\g<1>|b){1,2}(?(1)c|b)/,
              /(?:(a)|b){1,2}\1(?:(c)|b){1,2}\2/]

  patterns.each do |regexp|
    it "preserves matches and iteration preference for #{regexp.inspect}" do
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
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

  it 'preserves lazy iteration order through the normal conversion path' do
    [/((a)|b){1,3}\2/, /(?:(a)|b){0,3}\1/, /(?:(a+)|b){1,3}\1/,
     /(?:(a)|(b)){1,3}\1\2/].each do |greedy|
      lazy = Regexp.new(greedy.source.sub(/\{[0-9]+,[0-9]+\}/) { |interval| "#{interval}?" })
      inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('lazy bounded repetition', lazy, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(lazy, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
      end
    end
  end

  it 'keeps native quantifiers when every iteration updates referenced captures' do
    [/(a){2,4}\1/, /(a)+\1/, /(?:(a*)b){1,3}\1/].each do |regexp|
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2009, pass: compiler)
      expect(result.source).to eq(regexp.source)
      example = SecondPassCorpus.example('native repetition', regexp, ['', 'a', 'aa', 'aaaa', 'bb', 'aba', 'aabaa'])
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'numbers copied captures only when emitting and keeps logical identity' do
    tree, = SecondPassCorpus.prepare(/(?:(a)|b){2}\1/, JsRegex::Target::ES2009)
    original = compiler::Importer.call(tree)
    expanded = compiler::ExpandBoundedLoops.call(original)
    captures = []
    compiler.walk(expanded) { |part| captures << part if part.kind == :capture }
    expect(captures.length).to eq(2)
    expect(captures[0].reference).not_to equal(captures[1].reference)
    expect(captures[0].reference.capture).to equal(captures[1].reference.capture)
    history = expanded.children.last
    expect(history.kind).to eq(:history)
    expect(history.children.map(&:reference)).to eq(captures.reverse.map(&:reference))
    expect(compiler::Emitter.call(original).to_s).to eq('(?:(a)|b){2}\\1')
  end

  it 'retains values across longer runs and astral iterations' do
    examples = [
      SecondPassCorpus.example('variable width', /\A(?:(ab+)|a){1,3}\1\z/, %w[abaab abbaabb aba ababb]),
      SecondPassCorpus.example('astral', /\A(?:(😋)|b){1,3}\1\z/, %w[😋b😋 b 😋bb😋]),
    ]
    examples.each do |example|
      result = SecondPassCorpus.convert(example.regexp, target: JsRegex::Target::ES2018, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'retains the final empty capture in bounded nullable repetitions' do
    [/\A(a*){0,2}\1\z/, /\A(a*?){1,3}(?(1)b|a)\1?/,
     /\A(a*){3}\1\z/, /\A(?:(a*)|b){1,3}\1\z/].each do |regexp|
      example = SecondPassCorpus.example('empty iterations', regexp,
                                         (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) })
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2009, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'distinguishes stable empty captures from empty updates at a different position' do
    ['(?:(a*)|b|c)', '(?:(a*?)|b)', '(?:(a*)b?|c)', '((a)?b?)']
      .product(['{1,3}', '{1,3}?', '{2,4}', '{2,4}?']).each do |body, quantity|
      regexp = Regexp.new(body + quantity + '(?(1)b|a)\\1?')
      inputs = (0..5).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('empty update position', regexp, inputs)
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

  it 'rejects self-referential loops instead of assuming previous-iteration semantics' do
    tree, = SecondPassCorpus.prepare(/(a|\1b){2}\1/, JsRegex::Target::ES2009)
    expect { compiler.call(tree) }.to raise_error(compiler::Unsupported, /self-references/)
  end

  it 'selects the latest participating value check, including empty and absent values' do
    bodies = ['(?:(a*)|b)', '(?:(a+)|b)', '(?:(a)|b)']
    bodies.product(['{0,3}', '{1,3}', '{1,3}?'], ['', '(?!']).each do |body, quantity, assertion|
      # Ruby's conditional models a raw JS value check: absent means empty.
      # Exercise the converter-tree boundary, replacing only that conditional.
      check = '(?(1)\\1|)'
      tail = assertion.empty? ? check : assertion + check + ')a'
      regexp = Regexp.new('\\A' + body + quantity + tail + '\\z')
      inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('split value check', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        tree, = SecondPassCorpus.prepare(regexp, target)
        replace = lambda do |node|
          next if node.instance_of?(String)
          if node.type == :conditional
            node.update(type: :capture_check, children: ["\\#{node.reference}"])
          else
            node.children.each { |child| replace.call(child) }
          end
        end
        replace.call(tree)
        result = SecondPassCorpus::Result.new(source: compiler.call(tree).to_s, options: '', warnings: [])
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example)),
          "#{regexp.inspect} on #{target}"
      end
    end
  end

  it 'preserves empty-iteration stopping across bounds and quantifier preferences' do
    inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    bodies = ['(a*)', '(a*?)', '(?:(a*)|b)', '(?:(a*)?b)', '(?:(a*)|(b*))']
    bodies.product([[0, 2], [1, 3], [3, 3], [2, 4]], [false, true]).each do |body, (minimum, maximum), lazy|
      interval = "{#{minimum},#{maximum}}"
      suffix = '(?(1)b|a)\\1?'
      regexp = Regexp.new(body + interval + (lazy ? '?' : '') + suffix)
      example = SecondPassCorpus.example('nullable bound matrix', regexp, inputs)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2009, pass: compiler)
      actual = SecondPassCorpus.actual(@context, example, result)
      expected = SecondPassCorpus.expected(example)
      differences = inputs.each_index.select { |index| actual[index] != expected[index] }
      expect(differences.map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty,
        regexp.inspect
    end
  end

  it 'permits scalar empty updates to stop before an unbounded minimum' do
    inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    bodies = ['a*', 'a|', 'a*b*', 'a*?', '|a']
    bodies.product([2, 3, 4], ['', '?'], [false, true]).each do |body, minimum, mode, anchored|
      source = '(' + body + '){' + minimum.to_s + ',}' + mode + '(?(1)b|a)'
      regexp = Regexp.new(anchored ? '\\A' + source + '\\z' : source)
      example = SecondPassCorpus.example('nullable unbounded minimum', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'preserves empty-first ordering after a condition removes the value read' do
    regexp = /(a*?b*?){2,}(?(1)b|a)/
    expect(regexp.match('bb')[0]).to eq('b')
    example = SecondPassCorpus.example('specialized empty update', regexp, %w[bb ab abba aabbbb])
    JsRegex::Target::SUPPORTED.each do |target|
      result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'preserves empty-first ordering when bounded captures have no value reads' do
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    ['a*?', '|a', 'a*?b*?'].product(['{2,3}', '{3,4}', '{3,4}?'], ['', 'b', 'ab']).each do |body, quantity, tail|
      regexp = Regexp.new('(' + body + ')' + quantity + tail)
      example = SecondPassCorpus.example('unobserved empty update', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'threads value continuations through required prefixes and identical capture updates' do
    inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    ['a*', 'a*?', 'a*b*', 'a*?b*?'].product(['{2,}', '{3,}?', '{2,4}'],
                                          ['\\1\\2a', '(?!\\2)a', '(?(2)b|a)\\1?'], [false, true]).each do |body, quantity, tail, anchored|
      source = '((' + body + '))' + quantity + tail
      regexp = Regexp.new(anchored ? '\\A' + source + '\\z' : source)
      example = SecondPassCorpus.example('required prefix continuation', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'keeps independent empty updates in finite repetitions even when their values are never read' do
    inputs = (0..5).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    ['a*(b*)?', 'a*(b*)??', 'a*(a*)?', '(a*?)(b*?)'].product(
      ['{2,4}', '{3,4}?'], ['\\1a', '(?!\\1)a', '(?(1)b|a)\\1?'], [false, true]
    ).each do |body, quantity, tail, anchored|
      source = '(' + body + ')' + quantity + tail
      regexp = Regexp.new(anchored ? '\\A' + source + '\\z' : source)
      example = SecondPassCorpus.example('whole-iteration progress', regexp, inputs)
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

  it 'does not discard unobserved inner state across a required nullable prefix' do
    regexp = /(a*(b*)?){3,}?(?!\1)a/
    expect(regexp.match('ba').to_a).to eq(%w[ba b b])
    tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
    children = tree.children
    expect { compiler.call(tree) }.to raise_error(compiler::Unsupported)
    expect(tree.children).to equal(children)
  end
end
