# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/importer'
require 'js_regex/second_pass/compiler/emitter'
require 'js_regex/second_pass/compiler/lower_nullable_choices'
require 'js_regex/second_pass/compiler/resolve_references'

describe 'Compiler continuation lowering' do
  let(:compiler) { JsRegex::SecondPass::Compiler }

  def read(regexp)
    compiler::Importer.call(SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018).first)
  end

  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  it 'indexes definitions, value uses, and participation checks separately' do
    expression = read(/(a*)?\1(?(1)b|c)/)
    analysis = compiler::Analysis.new(expression)
    reference = analysis.captures.keys.first
    expect(analysis[expression].definitions).to eq([reference])
    expect(analysis[expression].references).to eq(reference => 2)
    expect(analysis.value_uses.fetch(reference).map(&:kind)).to eq([:backreference])
    expect(analysis.presence_uses.fetch(reference).map(&:kind)).to eq([:conditional])
    expect(analysis[expression].must_capture).to be_empty
    expect(analysis[expression].may_capture).to eq([reference])
  end

  it 'distinguishes required, optional, disabled, and negative-assertion captures' do
    expression = read(/(a)(b)?(c){0}(?!(d))/)
    analysis = compiler::Analysis.new(expression)
    references = analysis.captures.keys
    expect(analysis[expression].must_capture).to eq(references.take(1))
    expect(analysis[expression].may_capture).to eq(references.take(2))
    expect(analysis[expression].definitions).to eq(references)
  end

  it 'does not infer unconditional emptiness from assertions or opaque fragments' do
    expression = read(/(a)(a*)(?=a)(a)?/)
    analysis = compiler::Analysis.new(expression)
    expect(expression.children.map { |part| analysis[part].empty }).to eq([:never, :always, :unknown, :always])
    expect(analysis[expression].empty).to eq(:never)
    opaque = compiler::Expression.new(:opaque, ['(?!)'])
    expect(compiler::Analysis.new(opaque)[opaque].empty).to eq(:unknown)
  end

  it 'does not require captures from just one alternative or a missing else' do
    [/a|(b)/, /(a)?(?(1)(b))/, /(a)?(?(1)(b)|(c))/].each do |regexp|
      expression = read(regexp)
      expect(compiler::Analysis.new(expression)[expression].must_capture).to be_empty
    end
  end

  it 'counts shared reference subtrees at every emitted position' do
    expression = read(/(a*)?\1/)
    reference = expression.children.last
    shared = expression.with(children: [expression.children.first, reference, reference])
    analysis = compiler::Analysis.new(shared)
    expect(analysis[shared].references.fetch(reference.reference)).to eq(2)
    expect(compiler::LowerNullableChoices.call(shared)).not_to equal(shared)
  end

  it 'copies the prefix and continuation as one binding scope' do
    expression = read(/(a*)(b)\1\2/)
    prefix = expression.children.first
    tail = compiler::Expression.new(:sequence, expression.children.drop(1))
    continuation = compiler::Continuation.new(tail)
    first = continuation.branch(prefix)
    second = continuation.branch(prefix)
    emitted = compiler::Emitter.call(compiler::Expression.new(:choice, [first, second]))
    expect(emitted.to_s).to eq('(a*)(b)\\1\\2|(a*)(b)\\3\\4')
    expect(compiler::Emitter.call(expression).to_s).to eq('(a*)(b)\\1\\2')
  end

  patterns = [/(a*)?\1/, /(a*)??\1/, /(a*)?\1?/, /(a*)??\1?/, /(a*)?(?(1)b|a)/,
              /(a*)??(?(1)b|a)/, /(a*)?(b)\1\2/, /(a*)?(b*)?\1\2/,
              /a*(b*)?(?(1)c|a)\1?/, /((a*)?\2)/, /(?:(a*)?\1|b)/,
              /(?<x>a*)?(?<x>b*)?\k<x>/, /((?=a))?\1a/]
  patterns.each do |regexp|
    it "preserves ordered matching for #{regexp.inspect} after optional lowering" do
      if regexp == /(?<x>a*)?(?<x>b*)?\k<x>/ && Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1.3')
        skip 'Ruby oracle predates the duplicate-name fix: https://bugs.ruby-lang.org/issues/18631'
      end
      expression = read(regexp)
      lowered = compiler::LowerNullableChoices.call(expression)
      expect(lowered).not_to equal(expression)
      emitted = compiler::Emitter.call(compiler::ResolveReferences.call(lowered))
      inputs = (0..5).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example(regexp.inspect, regexp, inputs)
      result = SecondPassCorpus::Result.new(source: emitted.to_s, options: '')
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'does not move a continuation across a capture or repeated scope' do
    [/(a*(b*)?)\2/, /(?:(a*)?b)+\1/, /(?=(a*)?)\1/, /(?>x(a*)?)\1/].each do |regexp|
      expression = read(regexp)
      expect(compiler::LowerNullableChoices.call(expression)).to equal(expression)
    end
  end

  it 'does not rewrite unbounded loops using optional-choice rules' do
    [/\A(a*)*\1/, /(?:(a+)|(b+))+?\1\2/, /(?:(a+)|ab)+?(?(1)c|a)/].each do |regexp|
      expression = read(regexp)
      expect(compiler::LowerNullableChoices.call(expression)).to equal(expression)
    end
  end

  it 'keeps captures discarded by conditional specialization unmatched' do
    expression = read(/(a*)?(?(1)(b)|(c))\2\3/)
    lowered = compiler::LowerNullableChoices.call(expression)
    emitted = compiler::Emitter.call(compiler::ResolveReferences.call(lowered))
    example = SecondPassCorpus.example('discarded captures', /(a*)?(?(1)(b)|(c))\2\3/, %w[bb cc bbc ccb])
    result = SecondPassCorpus::Result.new(source: emitted.to_s, options: '')
    expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
  end

  it 'preserves the full corpus when optional lowering precedes the old pipeline' do
    SecondPassCorpus::CASES.each do |example|
      example.targets.each do |target|
        tree, context = SecondPassCorpus.prepare(example.regexp, target)
        lowered = compiler::LowerNullableChoices.call(compiler::Importer.call(tree))
        emitted = JsRegex::SecondPass.call(compiler::Emitter.call(lowered))
        result = SecondPassCorpus::Result.new(source: emitted.to_s, options: context.required_options.join)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example)),
          "#{example.name} on #{target}"
      end
    end
  end
end
