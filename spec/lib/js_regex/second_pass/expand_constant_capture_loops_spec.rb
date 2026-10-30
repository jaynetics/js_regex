# frozen_string_literal: true

describe JsRegex::SecondPass::ExpandConstantCaptureLoops do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'leaves loops without referenced captures unchanged' do
    expect(/(?:(a)|b)+/).to stay_the_same
  end

  it 'leaves captures with several possible values to the other steps' do
    expect(/(?:(a+)|(b))+?\1\2/).to stay_the_same
  end

  it 'retains constant captures made on different iterations' do
    expect(/\A(?:(a)|(b))+\1\2\z/).to keep_matching('abab', 'aabbab', 'babaab')
      .and keep_not_matching('ab', 'abb', 'aba', 'aabb')
  end

  it 'uses retained captures in later iterations even when branches overlap' do
    expect(/\A(?:(a)|ab\1)+\z/).to keep_matching('a', 'aa', 'aaba')
      .and keep_not_matching('ab', 'aba', 'aababa')
  end

  it 'rejects a forward reference until an earlier iteration has captured it' do
    expect(/\A(?:b\1|(a))+\z/).to keep_matching('a', 'aba', 'aaba')
      .and keep_not_matching('ba', 'b', 'ab')
  end

  it 'checks retained participation in conditional loop branches that share a prefix' do
    expect(/\A(?:(a)|(?(1)ab|c))+\1\z/).to keep_matching('aa', 'aaba', 'caaba')
      .and keep_not_matching('c', 'ba', 'aca')
  end

  it 'keeps lazy match order when two captures share a prefix' do
    conversions(/(?:(aa)|(a))+?\1\2/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aaaaaa')[0]")).to eq('aaaaaa')
      expect(eval_js("#{converted}.exec('aaaaaaa')[0]")).to eq('aaaaaa')
      expect(eval_js("#{converted}.exec('aaaaaaaa')[0]")).to eq('aaaaaaaa')
    end
  end
end
