# frozen_string_literal: true

describe JsRegex::SecondPass::GuardMultiplexedBackrefs do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'tries mandatory captures with the same name in reverse order' do
    expect(/(?<x>a)(?<x>b)\k<x>/).to become('(a)(b)(?:\\2|\\1)')
  end

  it 'requires optional nonempty captures to participate without changing greediness' do
    expect(/\A(?<x>a)?(?<x>a)?\k<x>/).to keep_matching('aa', 'aaa')
      .and keep_not_matching('', 'a')
    conversions(/\A(?<x>a)?(?<x>a)?\k<x>/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aaa')[0]")).to eq('aaa')
    end
  end

  it 'marks lazy nullable optional captures for conditional expansion' do
    context = JsRegex::Converter::Context.new(target: ES2009)
    tree = JsRegex::Converter.convert(Regexp::Parser.parse(/(?<x>a*)(?<x>b*)??\k<x>/), context)
    described_class.call(tree)
    expect(tree.children.last.children[1].type).to eq(:conditional)
    expect(tree.children.last.children[1].reference).to eq(2)
  end

  it 'guards captures in negative assertions' do
    expect(/\A(?!(?<x>a))(?<x>b)\k<x>\z/).to keep_matching('bb')
      .and keep_not_matching('b', 'a', 'ab')
  end

end
