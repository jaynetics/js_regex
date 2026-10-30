# frozen_string_literal: true

describe JsRegex::SecondPass::DelimitBackrefs do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'leaves references without a following digit unchanged' do
    expect(/(a)\1b/).to stay_the_same
  end

  it 'separates a numeric reference from a following literal digit' do
    expect(/(a)\1 0/x).to become('(a)\\1(?:)0')
      .and keep_matching('aa0')
      .and keep_not_matching("a\b", 'aa')
  end

  it 'finds following digits across adjacent nodes' do
    reference = JsRegex::Node.new('\\12', reference: 12, type: :backref)
    tree = JsRegex::Node.new(reference, JsRegex::Node.new, JsRegex::Node.new('3'))
    described_class.call(tree)
    expect(tree.to_s).to eq('\\12(?:)3')
  end

  it 'finds digits through nested containers and dropped nodes' do
    reference = JsRegex::Node.new('\\12', reference: 12, type: :backref)
    dropped = JsRegex::Node.new('x', type: :dropped)
    following = JsRegex::Node.new(JsRegex::Node.new(dropped, JsRegex::Node.new('3')))
    tree = JsRegex::Node.new(reference, following)
    described_class.call(tree)
    expect(tree.to_s).to eq('\\12(?:)3')
  end

  it 'does not separate a reference from its quantifier' do
    expect(/(a)\1{2}0/).to stay_the_same
  end
end
