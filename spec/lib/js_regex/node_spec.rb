# frozen_string_literal: true

describe JsRegex::Node do
  it 'allows enumerable traversal to stop before visiting later descendants' do
    first = described_class.new('a')
    later = described_class.new('b')
    root = described_class.new(first, later)
    expect(later).not_to receive(:walk)
    expect(root.walk.any? { |node| node.equal?(first) }).to be(true)
  end

  it 'excludes the root from enumerable traversal when requested' do
    leaf = described_class.new('a')
    child = described_class.new(leaf)
    root = described_class.new(child)
    expect(root.walk(skip_self: true).to_a).to eq([child, leaf])
  end

  it 'preserves optionality when replacing a reference with failure' do
    quantifier = JsRegex::Node::Quantifier.new(0, 1)
    node = described_class.new('\\1', type: :backref, reference: 1).update(quantifier: quantifier)
    expect(node.make_unmatchable).to equal(node)
    expect(node.to_s).to eq('(?!)?')
    expect(node.reference).to be_nil
    expect(node.quantifier).to equal(quantifier)
  end

  it 'distinguishes an empty sequence from an alternation' do
    expect(described_class.new.alternation?).to be(false)
    expect(described_class.new(described_class.new('a', type: :branch)).alternation?).to be(true)
  end
end
