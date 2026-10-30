# frozen_string_literal: true

describe JsRegex::SecondPass::PreserveRepeatedCaptures do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'leaves repetitions without backreferences unchanged' do
    expect(/((a)|b)+/).to stay_the_same
  end

  it 'leaves captures that participate in every iteration unchanged' do
    expect(/(a)+\1/).to stay_the_same
  end

  it 'ends each update cycle with a participating capture' do
    context = JsRegex::Converter::Context.new(target: ES2009)
    tree = JsRegex::Converter.convert(Regexp::Parser.parse(/(?:(a)|b)+\1/), context)
    described_class.call(tree)

    expect(tree.children.last.type).to eq(:backref)
    expect(tree.children.last.reference).to eq(1)
    expect(tree.to_s).to eq('(?:(?:(?:(?!)|b){0,}?(?:(a)|b(?!))){1,}(?:(?!)|b){0,}|(?:(?!)|b)+)\\1')
  end

  it 'marks references to duplicated enclosing captures for history resolution' do
    context = JsRegex::Converter::Context.new(target: ES2009)
    tree = JsRegex::Converter.convert(Regexp::Parser.parse(/((a)|b)+\2\1/), context)
    described_class.call(tree)

    expect(tree.children[-2].reference).to eq(3)
    history = tree.children.last
    expect(history.type).to eq(:capture_backref)
    expect(history.children.map(&:reference)).to eq([5, 4, 2, 1])
  end

  it 'leaves ambiguous lazy loops with optional references unchanged' do
    expect(/(?:(a+)|a)+?\1?/).to stay_the_same
  end

  it 'retains variable-length captures when alternatives overlap' do
    expect(/\A(?:(ab+)|a)+\1\z/).to keep_matching('abaab', 'abbaabb')
  end

  it 'recognizes required references within enclosing branches and optional groups' do
    expect(/\A(?:(?:(a)|ab)+\1|c)\z/).to keep_matching('aa', 'aaba', 'c')
    expect(/\A(?:(?:(a)|ab)+\1)?\z/).to keep_matching('', 'aa', 'aaba')
  end

  it 'leaves overlapping loops with several retained captures unchanged' do
    expect(/(?:(aa)|(a))+?\1\2/).to stay_the_same
  end
end
