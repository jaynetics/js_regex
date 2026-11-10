# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/importer'
require 'js_regex/second_pass/compiler/emitter'

describe JsRegex::SecondPass::Compiler do
  let(:importer) { described_class::Importer }
  let(:emitter) { described_class::Emitter }

  def shape(node)
    return node if node.instance_of?(String)

    [node.type, node.reference, node.quantifier&.text, node.nonempty?, node.nullable?, node.children.map { |child| shape(child) }]
  end

  def capture(number, text)
    JsRegex::Node.new('(', text, ')', type: :captured_group, reference: number, nonempty: true)
  end

  def backref(number)
    JsRegex::Node.new("\\#{number}", type: :backref, reference: number)
  end

  SecondPassCorpus::CASES.each do |example|
    example.targets.each do |target|
      it "round-trips the converter tree for #{example.name} on #{target}" do
        original, = SecondPassCorpus.prepare(example.regexp, target)
        snapshot = shape(original)
        emitted = emitter.call(importer.call(original))
        expect(shape(emitted)).to eq(snapshot)
        expect(shape(original)).to eq(snapshot)

        expected = JsRegex::SecondPass.call(original).to_s
        expect(JsRegex::SecondPass.call(emitted).to_s).to eq(expected)
      end
    end
  end

  it 'separates repetition, captures, groups, choices, and assertions from syntax' do
    tree, = SecondPassCorpus.prepare(/(?:(a)|(?=b)b)+\1/, JsRegex::Target::ES2009)
    expression = importer.call(tree)
    kinds = []
    described_class.walk(expression) { |part| kinds << part.kind }
    expect(kinds).to include(:repeat, :group, :capture, :choice, :branch, :lookahead, :backreference)
    repeat = expression.children.first
    expect([repeat.quantity.min, repeat.quantity.max, repeat.quantity.mode]).to eq([1, -1, :greedy])
    choice = nil
    described_class.walk(expression) { |part| choice = part if part.kind == :choice }
    expect(choice.children.last.children.first).not_to eq('|')
  end

  it 'keeps atomic and absence fragments as explicit boundaries' do
    tree, = SecondPassCorpus.prepare(/(?>a|ab)(?~ab)/, JsRegex::Target::ES2009)
    expression = importer.call(tree)
    expect(expression.children.map(&:kind)).to eq([:atomic, :absence])
    expect(shape(emitter.call(expression))).to eq(shape(tree))
  end

  it 'keeps lookbehind polarity and dropped converter nodes' do
    tree, = SecondPassCorpus.prepare(/(?<=a)(?<!b)c(?#comment)/, JsRegex::Target::ES2018)
    expression = importer.call(tree)
    expect(expression.children.map(&:kind)).to include(:lookbehind, :negative_lookbehind, :dropped)
    expect(shape(emitter.call(expression))).to eq(shape(tree))
  end

  it 'distinguishes omitted branches from participating empty alternatives' do
    [/(a|\G|b)/, /\G|/, /a|/, /|a/, /\G|\G/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2009)
      expression = importer.call(tree)
      expect(shape(emitter.call(expression))).to eq(shape(tree))
    end
    tree, = SecondPassCorpus.prepare(/\G|/, JsRegex::Target::ES2009)
    choice = importer.call(tree).children.first
    expect(choice.children.map(&:kind)).to eq([:omitted_branch, :branch])
  end

  it 'numbers by final occurrence order, including forward references' do
    tree = JsRegex::Node.new(backref(7), capture(7, 'a'), capture(3, 'b'), backref(3))
    expression = importer.call(tree)
    expect(expression.children[0].reference).to equal(expression.children[1].reference)
    expect(emitter.call(expression).to_s).to eq('\\1(a)(b)\\2')

    reordered = expression.with(children: [expression.children[2], *expression.children[0..1], expression.children[3]])
    expect(emitter.call(reordered).to_s).to eq('(b)\\2(a)\\1')
    expect(emitter.call(expression).to_s).to eq('\\1(a)(b)\\2')
  end

  it 'gives copied captures new occurrences but preserves their logical identity' do
    tree = JsRegex::Node.new(capture(1, 'a'), JsRegex::Node.new('(?:', backref(2), capture(2, 'b'), backref(1), ')'))
    expression = importer.call(tree)
    original = expression.children.last
    copy = described_class.copy(original)
    first_capture = original.children[1].reference
    second_capture = copy.children[1].reference
    expect(second_capture).not_to equal(first_capture)
    expect(second_capture.capture).to equal(first_capture.capture)
    expect(copy.children[0].reference).to equal(second_capture)
    expect(copy.children[2].reference).to equal(original.children[2].reference)

    combined = expression.with(children: [*expression.children, copy])
    expect(emitter.call(combined).to_s).to eq('(a)(?:\\2(b)\\1)(?:\\3(b)\\1)')
  end

  it 'reconstructs every reference flavor from its binding' do
    first = capture(10, 'a')
    second = capture(20, 'b')
    value = JsRegex::Node.new('\\10', '(?:)', type: :capture_check, reference: 10)
    history = JsRegex::Node.new(backref(20), backref(10), type: :capture_backref)
    multiplex = JsRegex::Node.new(backref(20), backref(10), type: :multiplex_backref)
    condition = JsRegex::Node.new('(?:', JsRegex::Node.new('yes'), ')', type: :conditional, reference: 10)
    checks = JsRegex::Node.new(JsRegex::Node.new(reference: 20), JsRegex::Node.new(reference: 10))
    dynamic = JsRegex::Node.new(checks, JsRegex::Node.new('yes'), type: :capture_conditional)
    tree = JsRegex::Node.new(first, second, value, history, multiplex, condition, dynamic)
    emitted = emitter.call(importer.call(tree))
    expect(emitted.children[2].to_s).to eq('\\1(?:)')
    expect(emitted.children[3].children.map(&:reference)).to eq([2, 1])
    expect(emitted.children[4].children.map(&:reference)).to eq([2, 1])
    expect(emitted.children[5].reference).to eq(1)
    expect(emitted.children[6].children.first.children.map(&:reference)).to eq([2, 1])
    expect(emitted.children[3..6].map(&:type)).to eq(%i[capture_backref multiplex_backref conditional capture_conditional])
  end

  it 'rejects accidental reuse of one emitted capture occurrence' do
    expression = importer.call(capture(1, 'a'))
    duplicate = described_class::Expression.new(:sequence, [expression, expression])
    expect { emitter.call(duplicate) }.to raise_error(ArgumentError, /emitted twice/)
  end

  it 'shares unchanged immutable subtrees when copying' do
    tree = JsRegex::Node.new(capture(1, 'a'), JsRegex::Node.new('literal'))
    expression = importer.call(tree)
    copy = described_class.copy(expression)
    expect(copy).not_to equal(expression)
    expect(copy.children.first).not_to equal(expression.children.first)
    expect(copy.children.last).to equal(expression.children.last)
  end

  it 'rejects duplicate input numbers instead of guessing capture histories' do
    tree = JsRegex::Node.new(capture(1, 'a'), capture(1, 'b'))
    expect { importer.call(tree) }.to raise_error(ArgumentError, /duplicate input capture/)
  end

  it 'does not silently bind a removed capture to a different group' do
    expression = importer.call(JsRegex::Node.new(capture(1, 'a'), capture(2, 'b'), backref(1)))
    removed = expression.with(children: expression.children.drop(1))
    expect { emitter.call(removed) }.to raise_error(ArgumentError, /no emitted capture/)
  end

  it 'owns immutable strings and quantifiers and emits independent mutable nodes' do
    text = String.new('a')
    quantity = Regexp::Expression::Quantifier.construct(text: '+?')
    tree = JsRegex::Node.new(text).update(quantifier: quantity)
    expression = importer.call(tree)
    text.replace('b')
    quantity.text = '*'
    expect(expression).to be_frozen
    expect(expression.children).to be_frozen
    expect(expression.children.first.children.first).to be_frozen
    expect(expression.quantity.mode).to eq(:lazy)
    expect(emitter.call(expression).to_s).to eq('a+?')

    first = emitter.call(expression)
    first.children.first.replace('c')
    first.quantifier.text = '?'
    expect(emitter.call(expression).to_s).to eq('a+?')
  end

  it 'does not conflate unknown capture emptiness with a known empty capture' do
    unknown = JsRegex::Node.new('(', '(?=a)', ')', type: :captured_group, reference: 1)
    nullable = JsRegex::Node.new('(', ')', type: :captured_group, reference: 2, nullable: true)
    expression = importer.call(JsRegex::Node.new(unknown, nullable))
    expect(expression.children.map { |part| [part.nonempty, part.nullable] }).to eq([[false, false], [false, true]])
    expect(shape(emitter.call(expression))).to eq(shape(JsRegex::Node.new(unknown, nullable)))
  end
end
