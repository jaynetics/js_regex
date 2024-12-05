#
#
#
# WARNING: Some of the examples below contain literal tabs.
# Make sure that your IDE doesn't replace them with spaces.
#
#
#

require 'spec_helper'

describe LangRegex::Converter::LiteralConverter do
  it 'converts literal newlines into newline escapes' do
    expect(/

/).to\
    become(/\n\n/).and keep_matching("a\n\nb", with_results: %W[\n\n])
  end

  it 'does not add escapes to \\n' do
    expect(/\\n/).to stay_the_same.and keep_matching('\\n', with_results: %w[\\n])
  end

  it 'replaces literal carriage returns with \r' do
    expect(/#{"\r"}/).to\
    become(/\r/).and keep_matching("\r", with_results: %W[\r])
  end

  it 'replaces literal form feeds with \f' do
    expect(/#{"\f"}/).to\
    become(/\f/).and keep_matching("\f", with_results: %W[\f])
  end

  it 'replaces literal tabs with \t' do
    expect(/	/).to\
    become(/\t/).and keep_matching('	', with_results: ['	'])
  end

  it 'converts literal forward slashes to forward slash escapes' do
    expect(%r{//}).to\
    become('\\/\\/').and keep_matching('a//b', with_results: %w[//])
  end

  it 'does not double escape single-escaped forward slashes' do
    expect(%r{\/}).to\
    become('\\/').and keep_matching('a/b', with_results: %w[/])
  end

  it 'converts astral plane literals to surrogate pairs', targets: [ES2009] do
    expect(/😁/).to\
    become('(?:\uD83D\uDE01)').and keep_matching('😁', with_results: %w[😁])
  end

  it 'converts multiple astral plane literals to distinct surrogate pairs', targets: [ES2009] do
    expect(/😁😁/).to\
    become('(?:\uD83D\uDE01)(?:\uD83D\uDE01)')
      .and keep_matching('😁😁', with_results: %w[😁😁])
  end

  it 'converts astral plane chars inside a bmp literal run', targets: [ES2009] do
    expect(/a😁b/).to\
    become('a(?:\uD83D\uDE01)b')
      .and keep_matching('a😁b', with_results: %w[a😁b])
  end

  it 'wraps substitutional surrogate pairs to ensure correct quantification', targets: [ES2009] do
    expect(/😁{2}/).to\
    become('(?:\uD83D\uDE01){2}')
      .and keep_matching('😁😁😁😁', with_results: %w[😁😁 😁😁])
  end

  it 'keeps astral plane chars and adds the u-flag on ES2015+', targets: [ES2015, ES2018] do
    expect(/😁😁/)
      .to stay_the_same
      .and keep_matching('😁😁', with_results: %w[😁😁])
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
