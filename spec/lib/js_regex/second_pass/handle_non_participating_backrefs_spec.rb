# frozen_string_literal: true

describe JsRegex::SecondPass::HandleNonParticipatingBackrefs do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'preserves references to completed captures' do
    expect(/(a)\1/).to stay_the_same
  end

  it 'requires optional captures to participate when their backreferences are used' do
    expect(/(a)?b\1/).to keep_matching('aba')
      .and keep_not_matching('b', 'bbb')
  end

  it 'rejects references to captures that have not finished' do
    expect(/\1(a)/).to become('(?!)(a)')
    expect(/(a\1)/).to become('(a(?!))')
  end

  it 'rejects references to captures in another alternative' do
    expect(/(a)|\1/).to become('(a)|(?!)')
      .and keep_matching('a')
      .and keep_not_matching('', 'b')
  end

  it 'preserves references within the same branch and after nested alternatives' do
    expect(/(?:(a)\1|b)/).to stay_the_same
    expect(/(a)(?:b|c)\1/).to stay_the_same
  end

  it 'does not treat participation checks as ordinary backreferences' do
    tree = JsRegex::Node.new('\\1', reference: 1, type: :capture_check)
    described_class.call(tree)
    expect(tree.to_s).to eq('\\1')
  end

  it 'allows another branch or an optional backreference to skip the capture' do
    expect(/\A(a)?b(?:c|\1)\z/).to keep_matching('bc', 'aba')
      .and keep_not_matching('b')
    expect(/\A(a)?b\1?\z/).to keep_matching('b', 'ab', 'aba')
  end

  it 'requires captures nested in optional groups, alternatives, or negative assertions' do
    expect(/\A(?:(a))?b\1\z/).to keep_matching('aba').and keep_not_matching('b')
    expect(/\A(?:(a)|b)\1\z/).to keep_matching('aa').and keep_not_matching('b')
    expect(/\A(?!(a))b\1\z/).to keep_not_matching('b')
  end

  it 'requires nullable captures to participate when their references are mandatory' do
    expect(/\A(?:(a*)|b)\1\z/).to keep_matching('', 'aa').and keep_not_matching('b')
    expect(/\A(?:(a*)b)?c\1\z/).to keep_matching('bc', 'abca').and keep_not_matching('c')
    expect(/\A(a*){0}b\1\z/).to keep_not_matching('b')
  end

  it 'keeps enclosing optional groups and unrelated alternatives optional' do
    expect(/\A(?:(a*)b\1)?c\z/).to keep_matching('c', 'bc', 'abac')
    expect(/\A(?:(?:(a*)|b)\1|c)\z/).to keep_matching('', 'aa', 'c').and keep_not_matching('b')
  end

  it 'rejects nullable captures from successful negative assertions' do
    expect(/\A(?!(a*)a)b\1\z/).to keep_not_matching('b')
  end
end
