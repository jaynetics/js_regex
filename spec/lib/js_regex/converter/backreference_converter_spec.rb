# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::BackreferenceConverter do
  it 'preserves traditional numeric backreferences' do
    given_the_ruby_regexp(/(a)(b)(c)\2/)
    expect_js_regex_to_be(/(a)(b)(c)\2/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abc')
    expect_ruby_and_js_to_match(string: 'abcb')
  end

  it 'substitutes ab number backreferences ("\k<1>") with numeric ones' do
    given_the_ruby_regexp(/(a)(b)(c)\k<2>/)
    expect_js_regex_to_be(/(a)(b)(c)\2/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abc')
    expect_ruby_and_js_to_match(string: 'abcb')
  end

  it 'substitutes sq number backreferences ("\k\'1\'") with numeric ones' do
    given_the_ruby_regexp(/(a)(b)(c)\k'2'/)
    expect_js_regex_to_be(/(a)(b)(c)\2/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abc')
    expect_ruby_and_js_to_match(string: 'abcb')
  end

  it 'substitutes ab relative backreferences ("\k<-1>") with numeric ones' do
    given_the_ruby_regexp(/(a)(b)(c)\k<-1>/)
    expect_js_regex_to_be(/(a)(b)(c)\3/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abc')
    expect_ruby_and_js_to_match(string: 'abcc')
  end

  it 'substitutes sq relative backreferences ("\k\'-1\'") with numeric ones' do
    given_the_ruby_regexp(/(a)(b)(c)\k'-1'/)
    expect_js_regex_to_be(/(a)(b)(c)\3/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abc')
    expect_ruby_and_js_to_match(string: 'abcc')
  end

  it 'substitutes deep relative backreferences ("\k<-3>") with numeric ones' do
    given_the_ruby_regexp(/(a)(b)(c)\k<-3>/)
    expect_js_regex_to_be(/(a)(b)(c)\1/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abc')
    expect_ruby_and_js_to_match(string: 'abca')
  end

  it 'substitutes relative backreferences to nested groups correctly' do
    given_the_ruby_regexp(/(a(b)a)\k<-1>/)
    expect_js_regex_to_be(/(a(b)a)\2/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abaa')
    expect_ruby_and_js_to_match(string: 'abab')
  end

  it 'substitutes ab named backreferences ("\k<foo>") with numeric ones' do
    given_the_ruby_regexp(/(a)(?<foo>b)(c)\k<foo>/)
    expect_js_regex_to_be(/(a)(b)(c)\2/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abc')
    expect_ruby_and_js_to_match(string: 'abcb')
  end

  it 'substitutes sq named backreferences ("\k\'foo\'") with numeric ones' do
    given_the_ruby_regexp(/(a)(?'foo'b)(c)\k'foo'/)
    expect_js_regex_to_be(/(a)(b)(c)\2/)
    expect_no_warnings
    expect_ruby_and_js_not_to_match(string: 'abc')
    expect_ruby_and_js_to_match(string: 'abcb')
  end

  it 'marks backrefs for SecondPass conversion' do
    backref = Regexp::Parser.parse(/(a)\1/).last

    result = JsRegex::Converter.convert(backref)

    expect(result).to be_a JsRegex::Node
    expect(result.children.last.to_s).to eq '1'
    expect(result.children.last.type).to eq :backref_num
  end

  it 'drops recursion level backreferences with warning' do
    given_the_ruby_regexp(/(a)\k<1+1>/)
    expect_js_regex_to_be(/(a)/)
    expect_warning('number recursion ref')
  end

  context 'when there are preceding substitutions' do
    it 'increments traditional number backrefs accordingly' do
      given_the_ruby_regexp(/(?>aa|a)(?>aa|a)(X)\1/)
      expect_js_regex_to_be(/(?=(aa|a))\1(?:)(?=(aa|a))\2(?:)(X)\3/)
      expect_ruby_and_js_not_to_match(string: 'aaaaX')
      expect_ruby_and_js_to_match(string: 'aaaaXX')
    end

    it 'increments \k-style number backrefs accordingly' do
      given_the_ruby_regexp(/(?>aa|a)(?>aa|a)(X)\k<1>/)
      expect_js_regex_to_be(/(?=(aa|a))\1(?:)(?=(aa|a))\2(?:)(X)\3/)
      expect_ruby_and_js_not_to_match(string: 'aaaaX')
      expect_ruby_and_js_to_match(string: 'aaaaXX')
    end

    it 'increments relative backrefs accordingly' do
      given_the_ruby_regexp(/(?>aa|a)(?>aa|a)(X)\k<-1>/)
      expect_js_regex_to_be(/(?=(aa|a))\1(?:)(?=(aa|a))\2(?:)(X)\3/)
      expect_ruby_and_js_not_to_match(string: 'aaaaX')
      expect_ruby_and_js_to_match(string: 'aaaaXX')
    end

    it 'increments name backrefs accordingly' do
      given_the_ruby_regexp(/(?>aa|a)(?>aa|a)(?<foo>X)\k<foo>/)
      expect_js_regex_to_be(/(?=(aa|a))\1(?:)(?=(aa|a))\2(?:)(X)\3/)
      expect_ruby_and_js_not_to_match(string: 'aaaaX')
      expect_ruby_and_js_to_match(string: 'aaaaXX')
    end
  end

  context 'when there are group additions after the backref' do
    it 'does not increment traditional number backrefs' do
      given_the_ruby_regexp(/(a)\1_1(?>33|3)37/)
      expect_js_regex_to_be(/(a)\1_1(?=(33|3))\2(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'aa_1337')
      expect_ruby_and_js_to_match(string: 'aa_13337')
    end

    it 'does not increment \k-style number backrefs' do
      given_the_ruby_regexp(/(a)\k<1>_1(?>33|3)37/)
      expect_js_regex_to_be(/(a)\1_1(?=(33|3))\2(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'aa_1337')
      expect_ruby_and_js_to_match(string: 'aa_13337')
    end

    it 'does not increment relative number backrefs' do
      given_the_ruby_regexp(/(a)\k<-1>_1(?>33|3)37/)
      expect_js_regex_to_be(/(a)\1_1(?=(33|3))\2(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'aa_1337')
      expect_ruby_and_js_to_match(string: 'aa_13337')
    end

    it 'does not increment name backrefs' do
      given_the_ruby_regexp(/(?<foo>a)\k<foo>_1(?>33|3)37/)
      expect_js_regex_to_be(/(a)\1_1(?=(33|3))\2(?:)37/)
      expect_no_warnings
      expect_ruby_and_js_not_to_match(string: 'aa_1337')
      expect_ruby_and_js_to_match(string: 'aa_13337')
    end
  end

  context 'when there are group additions between the backref and its target' do
    it 'does not increment traditional number backrefs' do
      given_the_ruby_regexp(/(X)(?>aa|a)\1/)
      expect_js_regex_to_be(/(X)(?=(aa|a))\2(?:)\1/)
      expect_ruby_and_js_not_to_match(string: 'Xa')
      expect_ruby_and_js_to_match(string: 'XaX')
    end

    it 'does not increment \k-style number backrefs' do
      given_the_ruby_regexp(/(X)(?>aa|a)\k<1>/)
      expect_js_regex_to_be(/(X)(?=(aa|a))\2(?:)\1/)
      expect_ruby_and_js_not_to_match(string: 'Xa')
      expect_ruby_and_js_to_match(string: 'XaX')
    end

    it 'does not increment relative number backrefs' do
      given_the_ruby_regexp(/(X)(?>aa|a)\k<-1>/)
      expect_js_regex_to_be(/(X)(?=(aa|a))\2(?:)\1/)
      expect_ruby_and_js_not_to_match(string: 'Xa')
      expect_ruby_and_js_to_match(string: 'XaX')
    end

    it 'does not increment name backrefs' do
      given_the_ruby_regexp(/(?<foo>X)(?>aa|a)\k<foo>/)
      expect_js_regex_to_be(/(X)(?=(aa|a))\2(?:)\1/)
      expect_ruby_and_js_not_to_match(string: 'Xa')
      expect_ruby_and_js_to_match(string: 'XaX')
    end
  end

  context 'when dealing with subexp calls' do
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

    it 'drops whole-pattern recursion calls with warning' do
      given_the_ruby_regexp(/(a(b|\g<0>))/)
      expect_js_regex_to_be(/(a(b))/)
      expect_warning('whole-pattern recursion')
    end
  end
end
