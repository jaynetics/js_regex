require 'spec_helper'

describe LangRegex::Converter::BackreferenceConverter do
  it 'preserves traditional numeric backreferences' do
    expect(/(a)(b)(c)\2/)
      .to stay_the_same
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
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

  it 'substitutes ab named backreferences ("\k<foo>") with numeric ones', targets: [ES2009, ES2015] do
    expect(/(a)(?<foo>b)(c)\k<foo>/).to\
    become(/(a)(b)(c)\2/)
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'keeps ab named backreferences ("\k<foo>") on ES2018+', targets: [ES2018] do
    expect(/(a)(?<foo>b)(c)\k<foo>/)
      .to stay_the_same
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'substitutes sq named backreferences ("\k\'foo\'") with numeric ones', targets: [ES2009, ES2015] do
    expect(/(a)(?'foo'b)(c)\k'foo'/).to\
    become(/(a)(b)(c)\2/)
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'changes sq named backreferences ("\k\'foo\'") to ab named on ES2018+', targets: [ES2018] do
    expect(/(a)(?'foo'b)(c)\k'foo'/).to\
    become(/(a)(?<foo>b)(c)\k<foo>/)
      .and keep_matching('abcb')
      .and keep_not_matching('abc')
  end

  it 'marks backrefs for SecondPass conversion' do
    backref = Regexp::Parser.parse(/(a)\1/).last

    result = LangRegex::JsRegex.js_converter.convert(backref)

    expect(result).to be_a LangRegex::Node
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
      become(/(?=(aa|a))\1(?:)(?=(aa|a))\2(?:)(X)\3/)
        .and keep_matching('aaaaXX')
        .and keep_not_matching('aaaaX')
    end

    it 'increments \k-style number backrefs accordingly' do
      expect(/(?>aa|a)(?>aa|a)(X)\k<1>/).to\
      become(/(?=(aa|a))\1(?:)(?=(aa|a))\2(?:)(X)\3/)
        .and keep_matching('aaaaXX')
        .and keep_not_matching('aaaaX')
    end

    it 'increments relative backrefs accordingly' do
      expect(/(?>aa|a)(?>aa|a)(X)\k<-1>/).to\
      become(/(?=(aa|a))\1(?:)(?=(aa|a))\2(?:)(X)\3/)
        .and keep_matching('aaaaXX')
        .and keep_not_matching('aaaaX')
    end

    it 'increments name backrefs accordingly', targets: [ES2009, ES2015] do
      expect(/(?>aa|a)(?>aa|a)(?<foo>X)\k<foo>/).to\
      become(/(?=(aa|a))\1(?:)(?=(aa|a))\2(?:)(X)\3/)
        .and keep_matching('aaaaXX')
        .and keep_not_matching('aaaaX')
    end

    it 'keeps name backrefs on ES2018', targets: [ES2018] do
      expect(/(?>aa|a)(?<foo>X)\k<foo>(?>aa|a)/).to\
      become('(?=(aa|a))\1(?:)(?<foo>X)\k<foo>(?=(aa|a))\3(?:)')
    end
  end

  context 'when there are group additions after the backref' do
    it 'does not increment traditional number backrefs' do
      expect(/(a)\1_1(?>33|3)37/).to\
      become(/(a)\1_1(?=(33|3))\2(?:)37/)
        .and keep_matching('aa_13337')
        .and keep_not_matching('aa_1337')
    end

    it 'does not increment \k-style number backrefs' do
      expect(/(a)\k<1>_1(?>33|3)37/).to\
      become(/(a)\1_1(?=(33|3))\2(?:)37/)
        .and keep_matching('aa_13337')
        .and keep_not_matching('aa_1337')
    end

    it 'does not increment relative number backrefs' do
      expect(/(a)\k<-1>_1(?>33|3)37/).to\
      become(/(a)\1_1(?=(33|3))\2(?:)37/)
        .and keep_matching('aa_13337')
        .and keep_not_matching('aa_1337')
    end

    it 'does not increment name backrefs', targets: [ES2009, ES2015] do
      expect(/(?<foo>a)\k<foo>_1(?>33|3)37/).to\
      become(/(a)\1_1(?=(33|3))\2(?:)37/)
        .and keep_matching('aa_13337')
        .and keep_not_matching('aa_1337')
    end
  end

  context 'when there are group additions between the backref and its target' do
    it 'does not increment traditional number backrefs' do
      expect(/(X)(?>aa|a)\1/).to\
      become(/(X)(?=(aa|a))\2(?:)\1/)
        .and keep_matching('XaX')
        .and keep_not_matching('Xa')
    end

    it 'does not increment \k-style number backrefs' do
      expect(/(X)(?>aa|a)\k<1>/).to\
      become(/(X)(?=(aa|a))\2(?:)\1/)
        .and keep_matching('XaX')
        .and keep_not_matching('Xa')
    end

    it 'does not increment relative number backrefs' do
      expect(/(X)(?>aa|a)\k<-1>/).to\
      become(/(X)(?=(aa|a))\2(?:)\1/)
        .and keep_matching('XaX')
        .and keep_not_matching('Xa')
    end

    it 'does not increment name backrefs', targets: [ES2009, ES2015] do
      expect(/(?<foo>X)(?>aa|a)\k<foo>/).to\
      become(/(X)(?=(aa|a))\2(?:)\1/)
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

    it 'replaces named subexpression calls with the targeted subexpression', targets: [ES2009, ES2015] do
      expect(/(foo)(?<x>bar)(baz)\g<x>+/).to\
      become(/(foo)(bar)(baz)(bar)+/)
        .and keep_matching('foobarbazbar')
        .and keep_not_matching('foobarbaz')
    end

    it 'replaces named subexpression calls with the targeted subexpression', targets: [ES2018] do
      expect(/(foo)(?<x>bar)(baz)\g<x>+/).to\
      become(/(foo)(?<x>bar)(baz)(bar)+/)
    end

    it 'does not carry over the quantifier when replacing subexpression calls' do
      expect(/(foo){2}(bar)\g<1>/).to\
      become(/(foo){2}(bar)(foo)/).and keep_matching('foofoobarfoo')
    end

    it 'keeps backrefs correct when replacing subexpression calls' do
      expect(/(foo)\g<1>(bar)\2/).to\
      become(/(foo)(foo)(bar)\3/).and keep_matching('foofoobarbar')
    end

    it 'keeps backrefs correct when replacing named subexpression calls', targets: [ES2018] do
      expect('(?<a>foo)\g<a>(bar)\2').to\
      become('(?<a>foo)(foo)(bar)\3')
    end

    it 'keeps 5 levels of recursive calls with warning' do
      expect(/a|b\g<0>/).to\
      become(/a|b(?:a|b(?:a|b(?:a|b(?:a|b(?:a|b)))))/)
        .with_warning("Recursion for '\\g<0>' curtailed at 5 levels")
        .and keep_matching('ab', 'aaab', 'bab')
        .and keep_not_matching('b')
    end
  end
end
