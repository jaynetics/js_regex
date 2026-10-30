# frozen_string_literal: true

# Integration tests for the combined second pass. Individual steps are tested
# in the specs under second_pass/.
describe JsRegex::SecondPass do
  it 'leaves trees that do not need further processing unchanged' do
    expect(/foo/).to stay_the_same
  end

  it 'keeps possessive quantifiers of the target group' do
    expect(/-(<)?+a(?(1)>)/).to\
    become(/(?:-(?:(?=((<){0}))\1)a(?:(?:>){0}))|(?:-(?:(?=((<)))\3)a(?:(?:>)))/)
      .and keep_matching('-<a>', '-a')
      .and keep_not_matching('-<a', '-<<a')
  end

  it 'checks captures made by subexpression calls in conditions' do
    expect(/\A(a)?\g<1>(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
    expect(/\A(?<x>a)?\g<x>(?(<x>)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
  end

  it 'retains earlier participating captures when checking conditions' do
    expect(/\A\g<1>(a)?(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
    expect(/\A(a)\g<1>?(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
  end

  it 'recognizes participating empty captures made by required calls' do
    expect(/\A(a?)?\g<1>(?(1)b|c)\z/).to keep_matching('b', 'ab', 'aab')
      .and keep_not_matching('c', 'ac', 'aac')
  end

  it 'delimits backreferences after conditional expansion renumbers them' do
    expect(/\A(a)(?(1)b)\k<1>0\z/)
      .to keep_matching('aba0')
      .and keep_not_matching('ab0', "ab\b")
  end

  it 'expands nullable multiplexed references into guarded conditional permutations' do
    expect(/\A(?<x>a)?(?<x>b*)?\k<x>\z/)
      .to keep_matching('', 'a', 'aa', 'bb', 'abbbb')
      .and keep_not_matching('b', 'ab')
  end
end
