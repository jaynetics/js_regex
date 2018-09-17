# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::SecondPass do
  describe '::substitute_subexp_calls' do
    it 'replaces numbered subexpression calls with the targeted subexpression' do
      given_the_ruby_regexp(/(foo)(bar)\g<2>+/)
      expect_js_regex_to_be(/(foo)(bar)(bar)+/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'foobar')
      expect_ruby_and_js_to_match(string: 'foobarbar')
    end

    it 'replaces numbered subexpression calls with nested subexpressions' do
      given_the_ruby_regexp(/(foo(bar))\g<2>+/)
      expect_js_regex_to_be(/(foo(bar))(bar)+/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'foobar')
      expect_ruby_and_js_to_match(string: 'foobarbar')
    end

    it 'replaces relative subexpression calls with the targeted subexpression' do
      given_the_ruby_regexp(/(foo)(bar)(qux)\g<-2>+/)
      expect_js_regex_to_be(/(foo)(bar)(qux)(bar)+/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'foobarqux')
      expect_ruby_and_js_to_match(string: 'foobarquxbar')
    end

    it 'replaces forward subexpression calls with the targeted subexpression' do
      given_the_ruby_regexp(/(foo)\g<+2>(bar)(quz)/)
      expect_js_regex_to_be(/(foo)(quz)(bar)(quz)/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'foobarquz')
      expect_ruby_and_js_to_match(string: 'fooquzbarquz')
    end

    it 'replaces named subexpression calls with the targeted subexpression' do
      given_the_ruby_regexp(/(foo)(?<x>bar)(baz)\g<x>+/)
      expect_js_regex_to_be(/(foo)(bar)(baz)(bar)+/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'foobarbaz')
      expect_ruby_and_js_to_match(string: 'foobarbazbar')
    end

    it 'does not carry over the quantifier when replacing subexpression calls' do
      given_the_ruby_regexp(/(foo){2}(bar)\g<1>/)
      expect_js_regex_to_be(/(foo){2}(bar)(foo)/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'foofoobarfoo')
    end

    it 'keeps backrefs correct when replacing subexpression calls' do
      given_the_ruby_regexp(/(foo)\g<1>(bar)\2/)
      expect_js_regex_to_be(/(foo)(foo)(bar)\3/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'foofoobarbar')
    end
  end

  describe '::alternate_conditional_permutations' do
    it 'replaces one-branch conditionals with equivalent alternations' do
      given_the_ruby_regexp(/-(<)?a(?(1)>)-/)
      expect_js_regex_to_be(/(?:-(<){0}a(?:(?:>){0})-)|(?:-(<)a(?:(?:>))-)/)
      expect_ruby_and_js_to_match(string: '-a-')
      expect_ruby_and_js_to_match(string: '-<a>-')
      expect_ruby_and_js_not_to_match(string: '-<a-')
      expect_ruby_and_js_not_to_match(string: '-a>-')
    end

    it 'replaces two-branch conditionals with equivalent alternations' do
      given_the_ruby_regexp(/-(<)?a(?(1)>|b)-/)
      expect_js_regex_to_be(/(?:-(<){0}a(?:(?:>){0}(?:b))-)|(?:-(<)a(?:(?:>)(?:b){0})-)/)
      expect_ruby_and_js_to_match(string: '-ab-')
      expect_ruby_and_js_to_match(string: '-<a>-')
      expect_ruby_and_js_not_to_match(string: '-a>-')
      expect_ruby_and_js_not_to_match(string: '-<ab-')
      expect_ruby_and_js_not_to_match(string: '-<ab>-')
    end

    it 'replaces named conditionals with equivalent alternations' do
      given_the_ruby_regexp(/-(?<bar><)?a(?(<bar>)>)-/)
      expect_js_regex_to_be(/(?:-(<){0}a(?:(?:>){0})-)|(?:-(<)a(?:(?:>))-)/)
      expect_ruby_and_js_to_match(string: '-a-')
      expect_ruby_and_js_to_match(string: '-<a>-')
      expect_ruby_and_js_not_to_match(string: '-<a-')
      expect_ruby_and_js_not_to_match(string: '-a>-')
    end

    it 'replaces quantified conditionals with equivalent alternations' do
      given_the_ruby_regexp(/-(<)?a(?(1)>){3}-/)
      expect_js_regex_to_be(/(?:-(<){0}a(?:(?:>){0}){3}-)|(?:-(<)a(?:(?:>)){3}-)/)
      expect_ruby_and_js_to_match(string: '-a-')
      expect_ruby_and_js_to_match(string: '-<a>>>-')
      expect_ruby_and_js_not_to_match(string: '-<a>-')
    end

    it 'replaces successive conditionals with equivalent alternations' do
      given_the_ruby_regexp(/(<)?a(?(1)>)(<)?b(?(2)>)/)
      # expect_js_regex_to_be(/quite long/)
      expect_ruby_and_js_to_match(string: 'ab')
      expect_ruby_and_js_to_match(string: 'a<b>')
      expect_ruby_and_js_to_match(string: '<a>b')
      expect_ruby_and_js_to_match(string: '<a><b>')
      expect_ruby_and_js_not_to_match(string: 'a>b')
      expect_ruby_and_js_not_to_match(string: '<a><b')
    end

    it 'replaces nested conditionals with equivalent alternations' do
      given_the_ruby_regexp(/-(<)?(a)?b(?(2)(?(1)->|>>))-/)
      # expect_js_regex_to_be(/quite long/)
      expect_ruby_and_js_to_match(string: '-<ab->-')     # 1: true,  2: true
      expect_ruby_and_js_to_match(string: '-<b-')        # 1: true,  2: false
      expect_ruby_and_js_to_match(string: '-ab>>-')      # 1: false, 2: true
      expect_ruby_and_js_to_match(string: '--b-')        # 1: false, 2: false
      expect_ruby_and_js_not_to_match(string: '-<ab-')   # 1: true,  2: true
      expect_ruby_and_js_not_to_match(string: '-<ab>>-') # 1: true,  2: true
      expect_ruby_and_js_not_to_match(string: '-<ab>>-') # 1: true,  2: false
      expect_ruby_and_js_not_to_match(string: '--b>>-')  # 1: false, 2: false
    end

    it 'adapts backref numbers in the created alternations branches' do
      given_the_ruby_regexp(/()(?(1))\1/)
      expect_js_regex_to_be(/(?:(){0}(?:(?:){0})\1)|(?:()(?:(?:))\2)/)
      given_the_ruby_regexp(/(a)(b)(?(1)c)(d)\2/)
      expect_js_regex_to_be(/(?:(a){0}(b)(?:(?:c){0})(d)\2)|(?:(a)(b)(?:(?:c))(d)\5)/)
    end
  end
end
