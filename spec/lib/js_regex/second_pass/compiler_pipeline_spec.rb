# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe JsRegex::SecondPass::Compiler do
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  patterns = [/(a)\1/, /\1(a)/, /(a\1)/, /(a)|b\1/, /(a)?\1/, /(a)??\1/,
              /(a*)?\1/, /(a*)??\1/, /(?:(a)\1)?/, /(?!(a))b\1/,
              /(?=(a))\1/, /(?<=(a))\1/, /(a){0}\1/, /(a)?\1{2}/,
              /(?:(a)|b)\1/, /(?=(a)?b)\1/, /(?!(a)\1)b/, /(a)\g<1>?\1/,
              /(a)?(?(1)b|c)/, /(a)??(?(1)b|a)/, /(a*)?(?(1)b|a)/,
              /(a)?(?(1)(b)|(c))(?(2)\2|\3)/,
              /(a*)?(?(1)(b)|(c))(?(2)\2|\3)/,
              /(?<n>a)(?<n>b)\k<n>/, /(?<n>a)?(?<n>b)?\k<n>/,
              /(?<n>a*)?(?<n>b*)?\k<n>/,
              /(?<n>a)(?<n>aa)\k<n>a/, /(?<n>a)(?<n>aa)(?<n>b)\k<n>a/,
              /\A(a)?\g<1>(?(1)b|c)\z/, /\A\g<1>(a)?(?(1)b|c)\z/,
              /(?>a|ab)c/, /(a)?+a(?(1)b|c)/,
              /1(?>3)+37/, /(?>(a|ab))+\1/, /(?>(a|ab)){2,3}\1/,
              /(?:(a)\1)+\1/, /(?:(a)\1){2,3}\1/,
              /(?:(a)(?(1)b|c))+\1/,
              /(?~(a))\1/, /(?~(ab))\1/, /(?:(?!(a))b)+\1/,
              /(?:(?!(a)\1)b){2,3}/]

  patterns.each do |regexp|
    it "compiles #{regexp.inspect} without invoking the old pipeline" do
      if regexp == /(?<n>a*)?(?<n>b*)?\k<n>/ && Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1.3')
        skip 'Ruby oracle predates the duplicate-name fix: https://bugs.ruby-lang.org/issues/18631'
      end
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      inputs += %w[1337 137 13337 1333337 1237]
      example = SecondPassCorpus.example(regexp.inspect, regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        next if regexp.source.include?('(?<=') && target != JsRegex::Target::ES2018

        result = SecondPassCorpus.convert(regexp, target: target, pass: described_class)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example)),
          "#{regexp.inspect} on #{target}"
      end
    end
  end

  it 'preserves capture arrays and match positions where group layout is unchanged' do
    [/a(b)\1/, /(?<n>a)(?<n>b)\k<n>/, /(a)?\1/,
     /(?:(a)|ab)+?\1?/, /(?:(a+)|ab)+?\1?/, /(?:(a*)|b)*?\1?/].each do |regexp|
      example = SecondPassCorpus.example('capture layout', regexp, ['abb', 'aba', 'aa', '😋abb', '😋aa'], groups: true)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: described_class)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'uses the entire continuation when simplifying lazy loops inside captures' do
    [/((a+)+?)\1/, /((a+)*?)\1b/].each do |regexp|
      inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('enclosing continuation', regexp, inputs, groups: true)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: described_class)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'delimits final numeric references, including references after conditionals' do
    [/\A(a)\k<1>0\z/, /\A(a)(?(1)b)\k<1>0\z/, /\A(a*)?\k<1>0\z/].each do |regexp|
      example = SecondPassCorpus.example('delimiter', regexp, ['aa0', 'aba0', '0', 'a0', 'ab0', "ab\b"])
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2009, pass: described_class)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
    result = SecondPassCorpus.convert(/(a)\1{2}0/, target: JsRegex::Target::ES2009, pass: described_class)
    expect(result.source).to eq('(a)\\1{2}0')
  end

  it 'delimits value references across empty nodes but skips dropped output' do
    value = JsRegex::Node.new('\\1', type: :capture_check, reference: 1)
    tree = JsRegex::Node.new(value, JsRegex::Node.new('ignored', type: :dropped), JsRegex::Node.new, '0')
    described_class::DelimitReferences.call(tree)
    expect(tree.to_s).to eq('\\1(?:)0')
    described_class::DelimitReferences.call(tree)
    expect(tree.to_s).to eq('\\1(?:)0')
  end

  it 'returns the same root after a successful conversion' do
    tree, = SecondPassCorpus.prepare(/(a*)?\1/, JsRegex::Target::ES2009)
    expect(described_class.call(tree)).to equal(tree)
    expect(tree.to_s).to eq('(a*)\\1')
  end

  it 'leaves plain trees untouched without allocating the intermediate representation' do
    expect(described_class::Importer).not_to receive(:call)
    [/a+b?/, /(?:ab)+/, /(?:a|b){2}/, /[ab]+/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2009)
      children = tree.children
      expect(described_class.call(tree)).to equal(tree)
      expect(tree.children).to equal(children)
    end
  end

  it 'fails explicitly before changing the root when semantics are not implemented' do
    [/(?:(a+)|ab)+\1?/, /(?:(a+)|(b+))+?\1\2\1/, /(a+)\1\Kb/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      original_children = tree.children
      expect { described_class.call(tree) }.to raise_error(described_class::Unsupported)
      expect(tree.children).to equal(original_children)
    end
  end

  it 'distinguishes capture-history selection from duplicate-name fallback' do
    first = described_class::Occurrence.new
    second = described_class::Occurrence.new
    expression = described_class::Expression
    captures = [expression.new(:capture, ['a'], reference: first, nonempty: true),
                expression.new(:capture, ['b'], reference: second, nonempty: true)]
    references = [second, first].map { |ref| expression.new(:backreference, [], reference: ref) }
    tree = expression.new(:sequence, [*captures, expression.new(:history, references)])
    resolved = described_class::ResolveReferences.call(tree)
    expect(described_class::Emitter.call(resolved).to_s).to eq('(a)(b)\\2')
    multiplex = tree.with(children: [*captures, expression.new(:multiplex, references)])
    source = described_class::Emitter.call(described_class::ResolveReferences.call(multiplex)).to_s
    expect(@context.eval("new RegExp(#{source.to_json}).test('aba')")).to eq(true)
    expect(@context.eval("new RegExp('(a)(b)\\\\2').test('aba')")).to eq(false)

    quantity = described_class::Quantity.new(Regexp::Expression::Quantifier.construct(text: '?'))
    optional = expression.new(:repeat, [captures.last], quantity: quantity)
    history = tree.with(children: ['^', captures.first, optional, tree.children.last, '$'])
    source = described_class::Emitter.call(described_class::ResolveReferences.call(history)).to_s
    expect(@context.eval("['aa', 'abb', 'aba'].map(function(s) { return new RegExp(#{source.to_json}).test(s); })"))
      .to eq([true, true, false])
  end

  it 'resolves external and local references inside absence converter trees' do
    # Exercise the SecondPass boundary directly: the parser's inner_match_length
    # currently loses backreference targets while cloning an absence body.
    expression = described_class::Expression
    reference = described_class::Occurrence.new
    capture = expression.new(:capture, ['a'], reference: reference, nonempty: true)
    backref = expression.new(:backreference, [], reference: reference)
    external = expression.new(:absence, [backref, ')(?:.|\\n))*)'])
    internal = expression.new(:absence,
                              [expression.new(:sequence, [capture, backref]), ')(?:.|\\n))*(?:.|\\n){0,1})'])
    cases = [[/(a)(?~\1)b/, expression.new(:sequence, [capture, external, 'b'])],
             [/(?~(a)\1)b/, expression.new(:sequence, [internal, 'b'])]]
    cases.each do |regexp, original|
      tree = described_class::Emitter.call(original)
      result = SecondPassCorpus::Result.new(source: described_class.call(tree).to_s, options: '', warnings: [])
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('absence references', regexp, inputs, groups: true)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end
end
