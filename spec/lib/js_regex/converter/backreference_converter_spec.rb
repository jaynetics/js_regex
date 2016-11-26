# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::BackreferenceConverter do
  it 'preserves simple number backreferences' do
    given_the_ruby_regexp(/(a)\1/)
    expect_js_regex_to_be(/(a)\1/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a', with_results: [])
    expect_ruby_and_js_to_match_string('aa')
  end

  it 'drops ab-numbered backreferences ("\k") with warning' do
    given_the_ruby_regexp(/(a)\k<1>/)
    expect_js_regex_to_be(/(a)/)
    expect_warning
  end

  it 'drops sq-numbered backreferences ("\k") with warning' do
    given_the_ruby_regexp(/(a)\k'1'/)
    expect_js_regex_to_be(/(a)/)
    expect_warning
  end

  it 'preserves number backreferences that dont follow atomic groups' do
    given_the_ruby_regexp(/(a)\1_1(?>33|3)37/)
    expect_js_regex_to_be(/(a)\1_1(?=(33|3))\2(?:)37/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aa_1337', with_results: [])
    expect_ruby_and_js_to_match_string('aa_13337')
  end

  it 'drops number backreferences that follow atomic groups with warning' do
    # These are likely to be off, since they'd need to be incremented
    # depending on how many groups have been added for emulation
    # purposes between them and their target:
    #  -  /(?>aa|a)(X)\1/          would require incrementing by 1
    #  -  /(?>aa|a)(?>aa|a)(X)\1/  would require incrementing by 2
    #  -  /(?>aa|a)(X)(?>aa|a)\1/  would require incrementing by 1
    #  -  /(X)(?>aa|a)\1/          wouldn't require incrementing
    # c.f. group_converter_spec.rb
    given_the_ruby_regexp(/1(?>33|3)37(a)\1/)
    expect_js_regex_to_be(/1(?=(33|3))\1(?:)37(a)/)
    expect_warning('number backreference following a feature that '\
                   'changes the group count (such as an atomic group)')
  end
end
