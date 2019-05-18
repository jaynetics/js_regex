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
    expect(/

/).to\
    become(/\n\n/).and keep_matching("a\n\nb", with_results: %W[\n\n])
  end

  it 'does not add escapes to \\n' do
    expect(/\\n/).to stay_the_same.and keep_matching('\\n', with_results: %w[\\n])
  end

  it 'replaces literal carriage returns with \r' do
    carriage_return = "\r"
    expect(/#{carriage_return}/).to\
    become(/\r/).and keep_matching("\r", with_results: %W[\r])
  end

  it 'replaces literal form feeds with \f' do
    form_feed = "\f"
    expect(/#{form_feed}/).to\
    become(/\f/).and keep_matching("\f", with_results: %W[\f])
  end

  it 'replaces literal tabs with \t' do
    expect(/	/).to\
    become(/\t/).and keep_matching('	', with_results: ['	'])
  end

  it 'converts literal forward slashes to forward slash escapes' do
    expect(%r{//}).to\
    become(double(source: '\\/\\/')).and keep_matching('a//b', with_results: %w[//])
  end

  it 'does not double escape single-escaped forward slashes' do
    expect(%r{\/}).to\
    become(double(source: '\\/')).and keep_matching('a/b', with_results: %w[/])
  end

  it 'converts astral plane literals to surrogate pairs' do
    expect(/😁/).to\
    become(double(source: '(?:\\ud83d\\ude01)'))
      .and keep_matching('😁', with_results: %w[😁])
  end

  it 'converts multiple astral plane literals to distinct surrogate pairs' do
    expect(/😁😁/).to\
    become(double(source: '(?:\\ud83d\\ude01)(?:\\ud83d\\ude01)'))
      .and keep_matching('😁😁', with_results: %w[😁😁])
  end

  it 'wraps substitutional surrogate pairs to ensure correct quantification' do
    expect(/😁{2}/).to\
    become(double(source: '(?:\\ud83d\\ude01){2}'))
      .and keep_matching('😁😁😁😁', with_results: %w[😁😁 😁😁])
  end

  it 'converts to a swapcase set if a local i-option applies' do
    expect(/a(?i:b)c(?i)d/).to\
    become(/a(?:[bB])c[dD]/).and keep_matching('aBcD', with_results: %w[aBcD])
  end

  it 'converts a literal run to distinct, individually quantified sets' do
    expect(/a(?i)bc-yz{2}/).to\
    become(/a[bB][cC]-[yY][zZ]{2}/)
      .and keep_matching('aBc-YzZ', with_results: %w[aBc-YzZ])
  end

  it 'does not create a swapcase set for literals without case' do
    # expect it not to call the more expensive conversion
    expect_any_instance_of(described_class).not_to receive(:case_insensitivize)
    expect(/1(?i:2)3(?i)4/).to\
    become(/1(?:2)34/).and keep_matching('1234', with_results: %w[1234])
  end

  it 'warns for case-sensitive literals in case-insensitive regexes' do
    expect(/a(?-i)b/i).to\
    become(/ab/i).with_warning("nested case-sensitive literal 'b'")
  end

  it 'lets all other literals pass through' do
    expect(/aü_1>!/).to stay_the_same.and keep_matching('aü_1>!', with_results: %w[aü_1>!])
  end
end
