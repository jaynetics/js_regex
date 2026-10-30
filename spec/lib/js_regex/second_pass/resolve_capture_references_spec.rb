# frozen_string_literal: true

describe JsRegex::SecondPass::ResolveCaptureReferences do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  describe 'backreferences' do
    it 'uses the latest mandatory copy of a capture' do
      expect(/([ab])\g<1>\1/).to become('([ab])([ab])\\2')
    end

    it 'uses the latest participating copy of an optional capture' do
      expect(/\A\g<1>([ab])?\1\z/).to keep_matching('aa', 'bb', 'abb', 'baa')
        .and keep_not_matching('a', 'b', 'aba', 'bab')
    end

    it 'preserves greedy matching of optional copies' do
      conversions(/\A\g<1>(a)?\1/).each_value do |converted|
        expect(eval_js("#{converted}.exec('aaa')[0]")).to eq('aaa')
      end
    end

    it 'rejects references when no copy has finished capturing' do
      references = [1, 2].map { |position| JsRegex::Node.new("\\#{position}", reference: position, type: :backref) }
      tree = JsRegex::Node.new(*references, type: :capture_backref)
      described_class.call(tree)
      expect(tree.to_s).to eq('(?!)')
    end
  end

  describe 'conditions' do
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
end
