# frozen_string_literal: true

describe JsRegex::SecondPass::ExpandBoundedCaptureLoops do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'leaves loops without referenced captures unchanged' do
    expect(/((a)|b){2,4}/).to stay_the_same
  end

  it 'leaves nonempty captures that participate in every iteration unchanged' do
    expect(/(a){2,4}\1/).to stay_the_same
  end

  it 'leaves unbounded loops to the other steps' do
    expect(/(?:(a)|b)+\1/).to stay_the_same
  end

  it 'gives each iteration its own capture and records their matching order' do
    context = JsRegex::Converter::Context.new(target: ES2009)
    tree = JsRegex::Converter.convert(Regexp::Parser.parse(/(?:(a)|b){2}\1/), context)
    described_class.call(tree)

    expect(tree.children.first.quantifier).to be_nil
    reference = tree.children.last
    expect(reference.type).to eq(:capture_backref)
    expect(reference.children.map(&:reference)).to eq([2, 1])
  end
end
