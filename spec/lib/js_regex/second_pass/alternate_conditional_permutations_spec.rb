# frozen_string_literal: true

describe JsRegex::SecondPass::AlternateConditionalPermutations do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'leaves trees without conditionals unchanged' do
    expect(/foo/).to stay_the_same
  end

  it 'replaces one-branch conditionals with equivalent alternations' do
    expect(/-(<)?a(?(1)>)-/).to become('(?:-(){0}a(?:)-)|(?:-(<)a(?:(?:>))-)')
      .and keep_matching('-a-', '-<a>-')
      .and keep_not_matching('-<a-', '-a>-')
  end

  it 'replaces two-branch conditionals with equivalent alternations' do
    expect(/-(<)?a(?(1)>|b)-/).to become('(?:-(){0}a(?:(?:b))-)|(?:-(<)a(?:(?:>))-)')
      .and keep_matching('-ab-', '-<a>-')
      .and keep_not_matching('-a>-', '-<ab-', '-<ab>-')
  end

  it 'replaces named conditionals with equivalent alternations' do
    expect(/-(?<bar><)?a(?(<bar>)>)-/).to become('(?:-(){0}a(?:)-)|(?:-(<)a(?:(?:>))-)')
      .and keep_matching('-a-', '-<a>-')
      .and keep_not_matching('-<a-', '-a>-')
  end

  it 'replaces quantified conditionals with equivalent alternations' do
    expect(/-(<)?a(?(1)>){3}-/).to become('(?:-(){0}a(?:){3}-)|(?:-(<)a(?:(?:>)){3}-)')
      .and keep_matching('-a-', '-<a>>>-')
      .and keep_not_matching('-<a>-')
  end

  it 'keeps 0..(n>1) quantifiers of the target group' do
    expect(/-(<){,2}a(?(1)>)-/).to become('(?:-(){0}a(?:)-)|(?:-(<){1,2}a(?:(?:>))-)')
      .and keep_matching('-<a>-', '-<<a>-')
      .and keep_not_matching('-<a-', '-<<a-', '-a>-')
  end

  it 'keeps unbounded and reluctant quantifiers of the target group' do
    [/\A(a)*(?(1)b|c)\z/, /\A(a)*?(?(1)b|c)\z/,
     /\A(a){0,}(?(1)b|c)\z/].each do |regexp|
      expect(regexp).to keep_matching('c', 'ab', 'aab')
        .and keep_not_matching('b', 'ac', 'aac')
    end
  end

  it 'keeps zero-only conditional captures unmatchable in true permutations' do
    expect(/\A(a){0}(?(1)b|c)\z/).to keep_matching('c')
      .and keep_not_matching('ab', 'b', 'ac')
  end

  it 'does not remove mandatory captures in false permutations' do
    expect(/\Aa(b)(?(1)c|d)\z/).to keep_matching('abc')
      .and keep_not_matching('ad', 'abd', 'ac')
    expect(/\A(a)+(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('c', 'ac')
  end

  it 'requires enclosing optional groups and alternatives for true conditions' do
    expect(/\A(?:(a)|b)?(?(1)c|d)\z/).to keep_matching('ac', 'bd', 'd')
      .and keep_not_matching('c', 'bc', 'ad')
  end

  it 'replaces successive conditionals with equivalent alternations' do
    expect(/(<)?a(?(1)>)(<)?b(?(2)>)/).to keep_matching('ab', 'a<b>', '<a>b', '<a><b>')
      .and keep_not_matching('a>b', '<a><b')
  end

  it 'replaces nested conditionals with equivalent alternations' do
    expect(/-(<)?(a)?(b)(?(2)(?(1)->|>>))-/).to keep_matching('-<ab->-', '-<b-', '-ab>>-', '--b-')
      .and keep_not_matching('-<ab-', '-<ab>>-', '--b>>-')
  end

  it 'keeps nested capture slots unmatched when discarding their parent' do
    expect(/\A(a(b))?(?(1)c|d)(?(2)e|f)(g)\3\z/)
      .to keep_matching('abcegg', 'dfgg')
      .and keep_not_matching('degg', 'abcfgg', 'dfg', 'abceg')
  end

  it 'keeps later reference numbers when discarding nested conditional branches' do
    expect(/\A(a)?(?(1)(?(1)b|(c))|(d))(e)\4\z/)
      .to keep_matching('abee', 'dee')
      .and keep_not_matching('acee', 'abed', 'de', 'ee')
  end

  it 'adapts backref numbers in the created alternation branches' do
    expect(/()(?(1))\1/).to become('(?:((?!))(?:)\\1)|(?:()(?:(?:))\\2)')
    expect(/(a)(b)(?(1)c)(d)\2/)
      .to become('(?:((?!)a)(b)(?:)(d)\\2)|(?:(a)(b)(?:(?:c))(d)\\5)')
  end
end
