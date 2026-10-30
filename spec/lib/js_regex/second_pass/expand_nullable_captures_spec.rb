# frozen_string_literal: true

describe JsRegex::SecondPass::ExpandNullableCaptures do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'leaves required captures unchanged' do
    expect(/(a*)b\1/).to stay_the_same
  end

  it 'keeps the final empty capture of a lazy repeated character run' do
    expect(/(a*)+?\1/).to become('a*()')
      .and keep_capturing('' => ['', ''], 'a' => ['a', ''], 'aaab' => ['aaa', ''])
    expect(/([ab]*)*?\1/).to become('[ab]*()')
      .and keep_capturing('abba' => ['abba', ''], 'c' => ['', ''])
    expect(/((?:a)*)+?\1/).to become('(?:a)*()')
      .and keep_capturing('aaa' => ['aaa', ''])
    expect(/((a*)+?\2)a/).to keep_capturing('aaa' => ['aaa', 'aa', ''])
  end

  it 'does not collapse lazy runs when their continuation or body can change the ending' do
    [/(a*)+?\1b/, /(a*)+?\1?/, /(a*?)+?\1/, /((?:ab)*)+?\1/].each do |regexp|
      expect(regexp).to stay_the_same
    end
  end

  it 'leaves unreferenced optional captures unchanged' do
    expect(/(a*)?b/).to stay_the_same
  end

  it 'puts greedy and lazy optional choices in their original order' do
    [/\A(a*)?\1/, /\A(a*)??\1/].each do |regexp|
      context = JsRegex::Converter::Context.new(target: ES2009)
      tree = JsRegex::Converter.convert(Regexp::Parser.parse(regexp), context)
      described_class.call(tree)
      branches = tree.children[1].children[1].children
      first_capture = branches.first.children.first
      last_capture = branches.last.children[1]
      if regexp.source.include?('??')
        expect(first_capture.quantifier.max).to eq(0)
        expect(last_capture.quantifier).to be_nil
      else
        expect(first_capture.quantifier).to be_nil
        expect(last_capture.quantifier.max).to eq(0)
      end
    end
  end

  it 'copies the continuation into each alternative that can skip the capture' do
    expect(/\A(?:(a*)|b|d)(?:c|\1)\z/)
      .to become('^(?:(?:(a*)(?:c|\\1)$)|(?:b)(?:c|(?!))$|(?:d)(?:c|(?!))$)')
  end

  it 'copies the continuation into the choices of an optional parent' do
    expect(/\A(?:(a*)b)?c(?:d|\1)\z/)
      .to become('^(?:(?:(a*)bc(?:d|\\1)$)|(?:()){0}c(?:d|(?!))$)')
  end

  it 'selects conditional branches using each optional choice' do
    expect(/\A(a*)?(?(1)b|a)\1?/).to become('^(?:(a*)(?:(?:b))\\1?|(){0}(?:(?:a))(?!)?)')
    expect(/\A(a*)?(?(1)b)\z/).to keep_matching('', 'b', 'ab', 'aab')
      .and keep_not_matching('a')
  end

  it 'handles referenced captures nested inside the optional capture' do
    expect(/\A((a*))?\1\2\z/).to keep_matching('', 'aaa')
      .and keep_not_matching('a', 'aa')
  end

  it 'handles empty captures whose participation depends on an assertion' do
    expect(/\A((?=a))?a(?:b|\1)\z/).to keep_matching('a', 'ab')
      .and keep_not_matching('', 'b')
  end

  it 'keeps an empty loop ending outside the repeated nonempty captures' do
    context = JsRegex::Converter::Context.new(target: ES2009)
    tree = JsRegex::Converter.convert(Regexp::Parser.parse(/\A(a*)*\1\z/), context)
    described_class.call(tree)
    prefix, ending = tree.children[1].children
    expect(prefix.quantifier.text).to eq('*')
    present_ending = ending.children[1].children.first.children.first
    empty_capture = present_ending.children.first
    expect(empty_capture.type).to eq(:captured_group)
    expect(empty_capture.children).to eq(['(', ')'])
    expect(empty_capture.quantifier).to be_nil
  end
end
