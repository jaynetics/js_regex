require 'spec_helper'

describe LangRegex::Converter::AnchorConverter do
  it 'translates the beginning-of-string anchor "\A"' do
    expect(/\A\w/).to\
    become(/^\w/).and keep_matching('abc', with_results: %w[a])
  end

  it 'translates the end-of-string anchor "\z"' do
    expect(/\w\z/).to\
    become(/\w$/).and keep_matching('abc', with_results: %w[c])
  end

  it 'translates the end-of-string-with-optional-newline anchor "\Z"' do
    expect(/abc\Z/).to\
    become(/abc(?=\n?$)/)
      .and keep_matching('abc', "abc\n")
      .and keep_not_matching('abcdef', "abc\n\n")
  end

  it 'preserves the beginning-of-line anchor "^"' do
    expect(/^\w/).to stay_the_same.and keep_matching('abc', with_results: %w[a])
  end

  it 'preserves the end-of-line anchor "$"' do
    expect(/\w$/).to stay_the_same.and keep_matching('abc', with_results: %w[c])
  end

  it 'preserves the word-boundary anchor "\b" with a warning', targets: [ES2009, ES2015] do
    expect(/\w\b/)
      .to stay_the_same
      .with_warning("The anchor '\\b' at index 2 only works at ASCII word boundaries")
      .and keep_matching('abc', with_results: %w[c])
  end

  it 'uses a unicode-awary replacement for "\b" on ES2018+', targets: [ES2018] do
    expect(/\w\b/).to\
    become('\w(?:(?<=[\d\p{L}\p{M}\p{Pc}])(?=[^\d\p{L}\p{M}\p{Pc}]|$)'\
           '|(?<=[^\d\p{L}\p{M}\p{Pc}]|^)(?=[\d\p{L}\p{M}\p{Pc}]))')
      .with_options('u')
      .and keep_matching('abc tür', with_results: %w[c r])
  end

  it 'preserves the non-word-boundary anchor "\B" with a warning', targets: [ES2009, ES2015] do
    expect(/\w\B/)
      .to stay_the_same
      .with_warning("The anchor '\\B' at index 2 only works at ASCII word boundaries")
      .and keep_matching('abc', with_results: %w[a b])
  end

  it 'uses a unicode-awary replacement for "\B" on ES2018+', targets: [ES2018] do
    expect(/\w\B/).to\
    become(/\w(?<=[\d\p{L}\p{M}\p{Pc}])(?=[\d\p{L}\p{M}\p{Pc}])/)
      .with_options('u')
      .and keep_matching('abc tür', with_results: %w[a b t])
      # ^ this is correct; both in Ruby and JS, \w is is ascii-only by default
  end

  it 'drops the previous match anchor "\G" with warning' do
    expect(/(foo)\G/).to\
    become(/(foo)/).with_warning
  end

  it 'drops unknown anchors with warning' do
    expect([:anchor, :an_unknown_anchor]).to be_dropped_with_warning
  end
end
