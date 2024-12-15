require 'spec_helper'

describe LangRegex::SecondPass do
  describe '::alternate_conditional_permutations' do
    it 'replaces one-branch conditionals with equivalent alternations' do
      expect(/-(<)?a(?(1)>)-/).to\
      become(/(?:-(<){0}a(?:(?:>){0})-)|(?:-(<)a(?:(?:>))-)/)
        .and keep_matching('-a-', '-<a>-')
        .and keep_not_matching('-<a-', '-a>-')
    end

    it 'keeps 0..(n>1) quantifiers of the target group' do
      expect(/-(<){,2}a(?(1)>)-/).to\
      become(/(?:-(<){0}a(?:(?:>){0})-)|(?:-(<){1,2}a(?:(?:>))-)/)
        .and keep_matching('-<a>-', '-<<a>-')
        .and keep_not_matching('-<a-', '-<<a-', '-a>-')
    end

    it 'keeps possessive quantifiers of the target group' do
      expect(/-(<)?+a(?(1)>)/).to\
      become(/(?:-(?=((<){0}))\2(?:)a(?:(?:>){0}))|(?:-(?=((<)))\3(?:)a(?:(?:>)))/)
        .and keep_matching('-<a>', '-a')
        .and keep_not_matching('-<a', '-<<a')
    end

    it 'replaces two-branch conditionals with equivalent alternations' do
      expect(/-(<)?a(?(1)>|b)-/).to\
      become(/(?:-(<){0}a(?:(?:>){0}(?:b))-)|(?:-(<)a(?:(?:>)(?:b){0})-)/)
        .and keep_matching('-ab-', '-<a>-')
        .and keep_not_matching('-a>-', '-<ab-', '-<ab>-')
    end

    it 'replaces named conditionals with equivalent alternations' do
      expect(/-(?<bar><)?a(?(<bar>)>)-/).to\
      become(/(?:-(<){0}a(?:(?:>){0})-)|(?:-(<)a(?:(?:>))-)/)
        .and keep_matching('-a-', '-<a>-')
        .and keep_not_matching('-<a-', '-a>-')
    end

    it 'removes names from backrefs to avoid duplicate group name errors', targets: [ES2018] do
      expect(/(?<A><)?(?(<A>)>)\k'A'/).to\
      become(/(?:(<){0}(?:(?:>){0})\1)|(?:(<)(?:(?:>))\2)/)
    end

    it 'replaces quantified conditionals with equivalent alternations' do
      expect(/-(<)?a(?(1)>){3}-/).to\
      become(/(?:-(<){0}a(?:(?:>){0}){3}-)|(?:-(<)a(?:(?:>)){3}-)/)
        .and keep_matching('-a-', '-<a>>>-')
        .and keep_not_matching('-<a>-')
    end

    it 'replaces successive conditionals with equivalent alternations' do
      # resulting source is not speced because it is very long
      expect(/(<)?a(?(1)>)(<)?b(?(2)>)/)
        .to keep_matching('ab', 'a<b>', '<a>b', '<a><b>')
        .and keep_not_matching('a>b', '<a><b')
    end

    it 'replaces nested conditionals with equivalent alternations' do
      # resulting source is not speced because it is very long
      expect(/-(<)?(a)?(b)(?(2)(?(1)->|>>))-/)
      .to keep_matching(
        '-<ab->-', # 1: true,  2: true
        '-<b-',    # 1: true,  2: false
        '-ab>>-',  # 1: false, 2: true
        '--b-',    # 1: false, 2: false
      ).and keep_not_matching(
        '-<ab-',   # 1: true,  2: true
        '-<ab>>-', # 1: true,  2: true
        '-<ab>>-', # 1: true,  2: false
        '--b>>-',  # 1: false, 2: false
      )
    end

    it 'adapts backref numbers in the created alternations branches' do
      expect(/()(?(1))\1/).to\
      become(/(?:(){0}(?:(?:){0})\1)|(?:()(?:(?:))\2)/)
      expect(/(a)(b)(?(1)c)(d)\2/).to\
      become(/(?:(a){0}(b)(?:(?:c){0})(d)\2)|(?:(a)(b)(?:(?:c))(d)\5)/)
    end

    it 'does nothing if passed a tree that does not need further processing' do
      expect(/foo/).to stay_the_same
    end
  end
end
