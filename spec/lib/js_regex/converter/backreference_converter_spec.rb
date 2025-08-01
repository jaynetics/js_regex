# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::BackreferenceConverter do
  it 'preserves traditional numeric backreferences' do
    expect(/(a)(b)(c)\2/)
      .to stay_the_same
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'delimits traditional numeric backreferences in x-mode' do
    expect(/(a)\1 0/x).to\
    become(/(a)\1(?:)0/)
      .and keep_matching('aa0')
  end

  it 'substitutes ab number backreferences ("\k<1>") with numeric ones' do
    expect(/(a)(b)(c)\k<2>/).to\
    become(/(a)(b)(c)\2/)
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'substitutes sq number backreferences ("\k\'1\'") with numeric ones' do
    expect(/(a)(b)(c)\k'2'/).to\
    become(/(a)(b)(c)\2/)
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'substitutes ab relative backreferences ("\k<-1>") with numeric ones' do
    expect(/(a)(b)(c)\k<-1>/).to\
    become(/(a)(b)(c)\3/)
      .and keep_matching('abcc')
      .and keep_not_matching('abc')
  end

  it 'substitutes sq relative backreferences ("\k\'-1\'") with numeric ones' do
    expect(/(a)(b)(c)\k'-1'/).to\
    become(/(a)(b)(c)\3/)
      .and keep_matching('abcc')
      .and keep_not_matching('abc')
  end

  it 'substitutes deep relative backreferences ("\k<-3>") with numeric ones' do
    expect(/(a)(b)(c)\k<-3>/).to\
    become(/(a)(b)(c)\1/)
      .and keep_matching('abca')
      .and keep_not_matching('abc')
  end

  it 'substitutes relative backreferences to nested groups correctly' do
    expect(/(a(b)a)\k<-1>/).to\
    become(/(a(b)a)\2/)
      .and keep_matching('abab')
      .and keep_not_matching('abaa')
  end

  it 'substitutes ab named backreferences ("\k<foo>") with numeric ones' do
    expect(/(a)(?<foo>b)(c)\k<foo>/).to\
    become(/(a)(b)(c)\2/)
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'substitutes sq named backreferences ("\k\'foo\'") with numeric ones' do
    expect(/(a)(?'foo'b)(c)\k'foo'/).to\
    become(/(a)(b)(c)\2/)
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'marks backrefs for SecondPass conversion' do
    backref = Regexp::Parser.parse(/(a)\1/).last

    result = JsRegex::Converter.convert(backref)

    expect(result).to be_a JsRegex::Node
    expect(result.to_s).to eq '\1'
    expect(result.type).to eq :backref
  end

  it 'drops recursion level backreferences with warning' do
    expect(/(a)\k<1+1>/).to\
    become(/(a)/).with_warning('number recursion ref')
  end

  context 'when there are preceding substitutions' do
    it 'increments traditional number backrefs accordingly' do
      expect(/(?>aa|a)(?>aa|a)(X)\1/).to\
      become(/(?:(?=(aa|a))\1)(?:(?=(aa|a))\2)(X)\3/)
        .and keep_matching('aaaaXX')
        .and keep_not_matching('aaaaX')
    end

    it 'increments \k-style number backrefs accordingly' do
      expect(/(?>aa|a)(?>aa|a)(X)\k<1>/).to\
      become(/(?:(?=(aa|a))\1)(?:(?=(aa|a))\2)(X)\3/)
        .and keep_matching('aaaaXX')
        .and keep_not_matching('aaaaX')
    end

    it 'increments relative backrefs accordingly' do
      expect(/(?>aa|a)(?>aa|a)(X)\k<-1>/).to\
      become(/(?:(?=(aa|a))\1)(?:(?=(aa|a))\2)(X)\3/)
        .and keep_matching('aaaaXX')
        .and keep_not_matching('aaaaX')
    end

    it 'increments name backrefs accordingly', targets: [ES2009, ES2015] do
      expect(/(?>aa|a)(?>aa|a)(?<foo>X)\k<foo>/).to\
      become(/(?:(?=(aa|a))\1)(?:(?=(aa|a))\2)(X)\3/)
        .and keep_matching('aaaaXX')
        .and keep_not_matching('aaaaX')
    end

  end

  context 'when there are group additions after the backref' do
    it 'does not increment traditional number backrefs' do
      expect(/(a)\1_1(?>33|3)37/).to\
      become(/(a)\1_1(?:(?=(33|3))\2)37/)
        .and keep_matching('aa_13337')
        .and keep_not_matching('aa_1337')
    end

    it 'does not increment \k-style number backrefs' do
      expect(/(a)\k<1>_1(?>33|3)37/).to\
      become(/(a)\1_1(?:(?=(33|3))\2)37/)
        .and keep_matching('aa_13337')
        .and keep_not_matching('aa_1337')
    end

    it 'does not increment relative number backrefs' do
      expect(/(a)\k<-1>_1(?>33|3)37/).to\
      become(/(a)\1_1(?:(?=(33|3))\2)37/)
        .and keep_matching('aa_13337')
        .and keep_not_matching('aa_1337')
    end

    it 'does not increment name backrefs', targets: [ES2009, ES2015] do
      expect(/(?<foo>a)\k<foo>_1(?>33|3)37/).to\
      become(/(a)\1_1(?:(?=(33|3))\2)37/)
        .and keep_matching('aa_13337')
        .and keep_not_matching('aa_1337')
    end
  end

  context 'when there are group additions between the backref and its target' do
    it 'does not increment traditional number backrefs' do
      expect(/(X)(?>aa|a)\1/).to\
      become(/(X)(?:(?=(aa|a))\2)\1/)
        .and keep_matching('XaX')
        .and keep_not_matching('Xa')
    end

    it 'does not increment \k-style number backrefs' do
      expect(/(X)(?>aa|a)\k<1>/).to\
      become(/(X)(?:(?=(aa|a))\2)\1/)
        .and keep_matching('XaX')
        .and keep_not_matching('Xa')
    end

    it 'does not increment relative number backrefs' do
      expect(/(X)(?>aa|a)\k<-1>/).to\
      become(/(X)(?:(?=(aa|a))\2)\1/)
        .and keep_matching('XaX')
        .and keep_not_matching('Xa')
    end

    it 'does not increment name backrefs', targets: [ES2009, ES2015] do
      expect(/(?<foo>X)(?>aa|a)\k<foo>/).to\
      become(/(X)(?:(?=(aa|a))\2)\1/)
        .and keep_matching('XaX')
        .and keep_not_matching('Xa')
    end
  end

  context 'when dealing with subexp calls' do
    it 'replaces numbered subexpression calls with the targeted subexpression' do
      expect(/(foo)(bar)\g<2>+/).to\
      become(/(foo)(bar)(bar)+/)
        .and keep_matching('foobarbar')
        .and keep_not_matching('foobar')
    end

    it 'replaces numbered subexpression calls with nested subexpressions' do
      expect(/(foo(bar))\g<2>+/).to\
      become(/(foo(bar))(bar)+/)
        .and keep_matching('foobarbar')
        .and keep_not_matching('foobar')
    end

    it 'replaces relative subexpression calls with the targeted subexpression' do
      expect(/(foo)(bar)(qux)\g<-2>+/).to\
      become(/(foo)(bar)(qux)(bar)+/)
        .and keep_matching('foobarquxbar')
        .and keep_not_matching('foobarqux')
    end

    it 'replaces forward subexpression calls with the targeted subexpression' do
      expect(/(foo)\g<+2>(bar)(quz)/).to\
      become(/(foo)(quz)(bar)(quz)/)
        .and keep_matching('fooquzbarquz')
        .and keep_not_matching('foobarquz')
    end

    it 'replaces named subexpression calls with the targeted subexpression' do
      expect(/(foo)(?<x>bar)(baz)\g<x>+/).to\
      become(/(foo)(bar)(baz)(bar)+/)
        .and keep_matching('foobarbazbar')
        .and keep_not_matching('foobarbaz')
    end

    it 'replaces recursive subexpression calls' do
      expect(/(a\g<1>?b) (c)\2/).to\
      become(/(a(a(a(a(a(ab)?b)?b)?b)?b)?b) (c)\7/)
        .with_warning("Recursion for '\\g<1>?' curtailed at 5 levels")
    end

    it 'does not carry over the quantifier when replacing subexpression calls' do
      expect(/(foo){2}(bar)\g<1>/).to\
      become(/(foo){2}(bar)(foo)/).and keep_matching('foofoobarfoo')
    end

    it 'keeps backrefs correct when replacing subexpression calls' do
      expect(/(foo)\g<1>(bar)\2/).to\
      become(/(foo)(foo)(bar)\3/).and keep_matching('foofoobarbar')
    end

    it 'keeps backrefs correct when replacing named subexpression calls' do
      # Named groups are always converted to numbered
      expect('(?<a>foo)\g<a>(bar)\2').to\
      become('(foo)(foo)(bar)\3')
    end

    it 'keeps 5 levels of recursive calls with warning' do
      expect(/a|b\g<0>/).to\
      become(/a|b(?:a|b(?:a|b(?:a|b(?:a|b(?:a|b)))))/)
        .with_warning("Recursion for '\\g<0>' curtailed at 5 levels")
        .and keep_matching('ab', 'aaab', 'bab')
        .and keep_not_matching('b')
    end

    it 'handles indirect recursion between two groups' do
      expect(/(a\g<2>?b) - (c\g<1>?d)/).to\
      become(/(a(c(a(c(a(c(a(c(a(c(ab)?d)?b)?d)?b)?d)?b)?d)?b)?d)?b) - (c(a(c(a(c(a(c(a(c(a(cd)?b)?d)?b)?d)?b)?d)?b)?d)?b)?d)/)
        .with_warning(["Recursion for '\\g<2>?' curtailed at 5 levels",
                       "Recursion for '\\g<1>?' curtailed at 5 levels"])
    end

    it 'handles numbered recursive groups followed by backreferences correctly' do
      expect(/([ab])\g<-1>\k<1>/).to\
      become(/([ab])([ab])\2/)
        .and keep_matching('aaa', 'bbb')
        .and keep_not_matching('aba', 'bab', 'ab', 'a')
    end

    it 'handles named recursive groups followed by backreferences correctly' do
      # Same behavior but with named groups
      expect(/(?<a>[ab])\g<a>\k<a>/).to\
      become(/([ab])([ab])\2/)
        .and keep_matching('aaa', 'bbb')
        .and keep_not_matching('aba', 'bab', 'ab', 'a')
    end

    it 'handles nested group backreferences after parent group recursion' do
      expect(/(a([bc]))\g<1>\k<2>/).to\
      become(/(a([bc]))(a([bc]))\4/)
        .and keep_matching('ababb', 'acabb')
        .and keep_not_matching('ababc', 'acabc')
    end
  end

  context 'when handling multiplexed named groups' do
    it 'converts named backreferences to multiplexed groups as alternations', targets: [ES2009, ES2015] do
      expect(/(?<a>a)(?<a>b)\k<a>/).to\
      become(/(a)(b)(?:\1|\2)/)
        .and keep_matching('aba', 'abb')
        .and keep_not_matching('abc', 'ab')
    end

    it 'converts multiplexed named groups to numbered groups on ES2018+', targets: [ES2018] do
      # All named groups are converted to numbered groups, even on ES2018+
      expect(/(?<a>a)(?<a>b)\k<a>/).to\
      become(/(a)(b)(?:\1|\2)/)
        .and keep_matching('aba', 'abb')
        .and keep_not_matching('abc', 'ab')
    end

    it 'handles multiple multiplexed groups', targets: [ES2009, ES2015] do
      expect(/(?<x>a)(?<y>b)(?<x>c)\k<x>/).to\
      become(/(a)(b)(c)(?:\1|\3)/)
        .and keep_matching('abca', 'abcc')
        .and keep_not_matching('abcb', 'abcd')
    end

    it 'handles multiplexed groups with alternation', targets: [ES2009, ES2015] do
      expect(/(?<x>foo)|(?<x>bar)/).to\
      become(/(foo)|(bar)/)
        .and keep_matching('foo', 'bar')
        .and keep_not_matching('baz')
    end

    it 'handles single named group references normally', targets: [ES2009, ES2015] do
      expect(/(?<a>a)\k<a>/).to\
      become(/(a)\1/)
        .and keep_matching('aa')
        .and keep_not_matching('ab')
    end


    it 'handles multiplexed groups in x-mode', targets: [ES2009, ES2015] do
      expect(/(?<a> a ) (?<a> b ) \k<a> /x).to\
      become(/(a)(b)(?:\1|\2)/)
        .and keep_matching('aba', 'abb')
        .and keep_not_matching('abc')
    end
  end

  context 'when backreferences point to non-participating groups' do
    it 'handles forward references' do
      expect(/\1()/).to\
      become(/(?!)()/)
        .and keep_not_matching('', 'foo')
    end

    it 'handles backreferences within the same group' do
      expect(/(\1)/).to\
      become(/((?!))/)
        .and keep_not_matching('', 'foo')
    end

    it 'handles backreference to non-participating branches' do
      expect(/(a)|b\1/).to\
      become(/(a)|b(?!)/)
        .and keep_matching('a')
        .and keep_not_matching('b')
    end

    it 'handles named backreference to non-participating branch (?<n>a)|(?<n>)\k<n>' do
      expect(/(?<n>a)|(?<n>)\k<n>/).to\
      become(/(a)|()(?:\1|\2)/)
        .and keep_matching('a', '')
    end

    it 'handles backreferences to optional groups from branches' do
      # this has zero-length matches on 'b' and ''
      expect(/(a)?|b\1/).to stay_the_same.and keep_matching('a', 'b', '')
    end

    # TODO: https://github.com/jaynetics/js_regex/issues/26
    # Handling this would require generating a lot of permutations.
    # it 'handles backreferences to nested groups on branches' do
    #   expect(/((a)|b)+\2/).to\
    #   become(/((a)|b)+\2/) # TODO
    #     .and keep_matching('aa', 'aba', 'baa')
    #     .and keep_not_matching('a', 'b', 'ab', 'ba')
    # end

    it 'handles backreference to group that may capture empty string (a?)b\1' do
      expect(/(a?)b\1/).to stay_the_same.and keep_matching('aba', 'b')
    end
  end
end
