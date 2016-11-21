# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter::EscapeConverter do
  it 'lets backslashes pass through' do
    given_the_ruby_regexp(/\\/)
    expect_js_regex_to_be(/\\/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '\\', with_results: %w(\\))
  end

  it 'preserves escaped meta chars' do
    given_the_ruby_regexp(/\\A\\h/)
    expect_js_regex_to_be(/\\A\\h/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '\\A\\h', with_results: ['\\A\\h'])
  end

  it 'preserves escaped bol/eol anchors' do
    given_the_ruby_regexp(/\^\$/)
    expect_js_regex_to_be(/\^\$/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '^$', with_results: ['^$'])
  end

  it 'lets ascii escapes pass through' do
    given_the_ruby_regexp(/\x42/)
    expect_js_regex_to_be(/\x42/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ABC', with_results: ['B'])
  end

  it 'lets unicode / codepoint escapes pass through' do
    given_the_ruby_regexp(/\u263A/)
    expect_js_regex_to_be(/\u263A/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'A☺C', with_results: ['☺'])
  end

  it 'drops the bell char "\a" with warning' do
    given_the_ruby_regexp(/.\a/)
    expect_js_regex_to_be(/./)
    expect_warning
  end

  it 'drops the escape char "\e" with warning' do
    given_the_ruby_regexp(/.\e/)
    expect_js_regex_to_be(/./)
    expect_warning
  end

  it 'drops control sequences of the style "\C-x" with warning' do
    given_the_ruby_regexp(/.\C-d/)
    expect_js_regex_to_be(/./)
    expect_warning
  end

  it 'drops control sequences of the style "\cX" with warning' do
    given_the_ruby_regexp(/.\cD/)
    expect_js_regex_to_be(/./)
    expect_warning
  end

  it 'drops the subexpression rematcher "\G" with warning' do
    given_the_ruby_regexp(/(.)\G/)
    expect_js_regex_to_be(/(.)/)
    expect_warning
  end

  it 'drops ab-named subexpression calls ("\g") with warning' do
    given_the_ruby_regexp(/(?<x>.)\g<x>/)
    expect_js_regex_to_be(/(.)/)
    expect_warning
  end

  it 'drops sq-named subexpression calls ("\g") with warning' do
    given_the_ruby_regexp(/(?'x'.)\g'x'/)
    expect_js_regex_to_be(/(.)/)
    expect_warning
  end

  it 'drops the keep / lookbehind marker "\K" with warning' do
    given_the_ruby_regexp(/a\Kb/)
    expect_js_regex_to_be(/ab/)
    expect_warning
  end

  it 'preservers carriage returns ' do
    given_the_ruby_regexp(/\r/)
    expect_js_regex_to_be(/\r/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "abc\r123", with_results: ["\r"])
  end
end
