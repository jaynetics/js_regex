# frozen_string_literal: true

describe JsRegex::SecondPass do
  it 'can exclude impossible alternatives when finding absent captures' do
    capture = JsRegex::Node.new('(', 'a', ')', type: :captured_group, reference: 1)
    root = JsRegex::Node.new(JsRegex::Node.new(capture, type: :branch),
                            JsRegex::Node.new('|', '(?!)', type: :branch))
    analysis = described_class.new(root)
    expect(analysis.send(:potentially_absent_groups)).to eq([1])
    expect(analysis.send(:potentially_absent_groups, reachable_only: true)).to eq([])
  end

  it 'treats captures in dynamic conditional branches as optional in both modes' do
    capture = JsRegex::Node.new('(', 'a', ')', type: :captured_group, reference: 1)
    root = JsRegex::Node.new(JsRegex::Node.new, capture, JsRegex::Node.new('b'),
                            type: :capture_conditional)
    analysis = described_class.new(root)
    expect(analysis.send(:potentially_absent_groups)).to eq([1])
    expect(analysis.send(:potentially_absent_groups, reachable_only: true)).to eq([1])
  end
end
