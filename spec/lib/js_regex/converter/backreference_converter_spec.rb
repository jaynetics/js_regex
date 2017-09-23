# encoding: utf-8
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
    it 'does not increments traditional number backrefs' do
      given_the_ruby_regexp(/(X)(?>aa|a)\1/)
      expect_js_regex_to_be(/(X)(?=(aa|a))\2(?:)\1/)
      expect_ruby_and_js_not_to_match(string: 'Xa')
      expect_ruby_and_js_to_match(string: 'XaX')
    end

    it 'does not increments \k-style number backrefs' do
      given_the_ruby_regexp(/(X)(?>aa|a)\k<1>/)
      expect_js_regex_to_be(/(X)(?=(aa|a))\2(?:)\1/)
      expect_ruby_and_js_not_to_match(string: 'Xa')
      expect_ruby_and_js_to_match(string: 'XaX')
    end

    it 'does not increments relative number backrefs' do
      given_the_ruby_regexp(/(X)(?>aa|a)\k<-1>/)
      expect_js_regex_to_be(/(X)(?=(aa|a))\2(?:)\1/)
      expect_ruby_and_js_not_to_match(string: 'Xa')
      expect_ruby_and_js_to_match(string: 'XaX')
    end

    it 'does not increments name backrefs' do
      given_the_ruby_regexp(/(?<foo>X)(?>aa|a)\k<foo>/)
      expect_js_regex_to_be(/(X)(?=(aa|a))\2(?:)\1/)
      expect_ruby_and_js_not_to_match(string: 'Xa')
      expect_ruby_and_js_to_match(string: 'XaX')
    end
  end
end
