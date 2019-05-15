# frozen_string_literal: true

#
#
#
# WARNING: Some of the examples below contain literal tabs.
# Make sure that your IDE doesn't replace them with spaces.
#
#
#

require 'spec_helper'

describe JsRegex::Converter::LiteralConverter do
  it 'converts literal newlines into newline escapes' do
    given_the_ruby_regexp(/

/)
    expect_js_regex_to_be(/\n\n/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "a\n\nb", with_results: %W[\n\n])
  end

  it 'does not add escapes to \\n' do
    given_the_ruby_regexp(/\\n/)
    expect_js_regex_to_be(/\\n/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '\\n', with_results: %w[\\n])
  end

  it 'replaces literal carriage returns with \r' do
    carriage_return = "\r"
    given_the_ruby_regexp(/#{carriage_return}/)
    expect_js_regex_to_be(/\r/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "\r", with_results: %W[\r])
  end

  it 'replaces literal form feeds with \f' do
    form_feed = "\f"
    given_the_ruby_regexp(/#{form_feed}/)
    expect_js_regex_to_be(/\f/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "\f", with_results: %W[\f])
  end

  it 'replaces literal tabs with \t' do
    given_the_ruby_regexp(/	/)
    expect_js_regex_to_be(/\t/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '	', with_results: ['	'])
  end

  it 'converts literal forward slashes to forward slash escapes' do
    given_the_ruby_regexp(%r{//})
    expect(js_regex_source).to eq('\\/\\/')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a//b', with_results: %w[//])
  end

  it 'does not double escape single-escaped forward slashes' do
    # c.f. https://github.com/janosch-x/js_regex/issues/6
    given_the_ruby_regexp(%r{\/})
    expect(js_regex_source).to eq('\\/')
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a/b', with_results: %w[/])
  end

  it 'converts astral plane literals to surrogate pairs' do
    given_the_ruby_regexp(/😁/)
    expect(js_regex_source).to eq('(?:\\ud83d\\ude01)')
    expect_ruby_and_js_to_match(string: '😁', with_results: %w[😁])
  end

  it 'converts multiple astral plane literals to surrogate pairs' do
    given_the_ruby_regexp(/😁😁/)
    expect(js_regex_source).to eq('(?:\\ud83d\\ude01)(?:\\ud83d\\ude01)')
    expect_ruby_and_js_to_match(string: '😁😁', with_results: %w[😁😁])
  end

  it 'wraps substitutional surrogate pairs to ensure correct quantification' do
    given_the_ruby_regexp(/😁{2}/)
    expect(js_regex_source).to eq('(?:\\ud83d\\ude01){2}')
    expect_ruby_and_js_to_match(string: '😁😁😁😁', with_results: %w[😁😁 😁😁])
  end

  it 'converts to a swapcase set if a local i-option applies' do
    given_the_ruby_regexp(/a(?i:b)c(?i)d/)
    expect_js_regex_to_be(/a(?:[bB])c[dD]/)
    expect_ruby_and_js_to_match(string: 'aBcD', with_results: %w[aBcD])
  end

  it 'converts a literal run to distinct, individually quantified sets' do
    given_the_ruby_regexp(/a(?i)bc-yz{2}/)
    expect_js_regex_to_be(/a[bB][cC]-[yY][zZ]{2}/)
    expect_ruby_and_js_to_match(string: 'aBc-YzZ', with_results: %w[aBc-YzZ])
  end

  it 'does not create a swapcase set for literals without case' do
    given_the_ruby_regexp(/1(?i:2)3(?i)4/)
    expect_js_regex_to_be(/1(?:2)34/)
    expect_ruby_and_js_to_match(string: '1234', with_results: %w[1234])
  end

  it 'does not call the more expensive conversion for literals without case' do
    expect_any_instance_of(described_class).not_to receive(:case_insensitivize)
    given_the_ruby_regexp(/1(?i:2)3(?i)4/)
  end

  it 'warns for case-sensitive literals in case-insensitive regexes' do
    given_the_ruby_regexp(/a(?-i)b/i)
    expect_warning("nested case-sensitive literal 'b'")
    expect_js_regex_to_be(/ab/i)
  end

  it 'lets all other literals pass through' do
    given_the_ruby_regexp(/aü_1>!/)
    expect_js_regex_to_be(/aü_1>!/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aü_1>!', with_results: %w[aü_1>!])
  end
end
