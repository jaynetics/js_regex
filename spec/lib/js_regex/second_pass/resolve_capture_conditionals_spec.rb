# frozen_string_literal: true

describe JsRegex::SecondPass::ResolveCaptureConditionals do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'leaves ordinary conditionals for the permutation step' do
    tree = JsRegex::Node.new(type: :conditional, reference: 1)
    expect(described_class.call(tree)).to equal(tree)
    expect(tree.type).to eq(:conditional)
  end

  it 'checks all copies of a capture made by subexpression calls' do
    expect(/\A(a)?\g<1>(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
  end

  it 'uses an earlier capture when a later optional copy is skipped' do
    expect(/\A\g<1>(a)?(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
  end

  it 'supports conditions without an else branch' do
    expect(/\A(a)?\g<1>?(?(1)b)\z/).to keep_matching('', 'ab', 'aab')
      .and keep_not_matching('b', 'a', 'aa')
  end
end
