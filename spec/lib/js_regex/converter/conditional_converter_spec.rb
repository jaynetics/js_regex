# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter::ConditionalConverter do
  it 'makes conditional groups non-conditional with warning',
     if: ruby_version_at_least?('2.0') do
    given_the_ruby_regexp(Regexp.new('(a)?(?(1)b|c)'))
    expect_js_regex_to_be(Regexp.new('(a)?(b|c)'))
    expect_warning
  end

  it 'makes ab-named conditional groups non-conditional with warning',
     if: ruby_version_at_least?('2.0') do
    given_the_ruby_regexp(Regexp.new('(?<condition>a)?(?(<condition>)b|c)'))
    expect_js_regex_to_be(Regexp.new('(a)?(b|c)'))
    expect_warning
  end

  it 'makes sq-named conditional groups non-conditional with warning',
     if: ruby_version_at_least?('2.0') do
    given_the_ruby_regexp(Regexp.new("(?'condition'a)?(?('condition')b|c)"))
    expect_js_regex_to_be(Regexp.new('(a)?(b|c)'))
    expect_warning
  end
end
