# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::AnchorConverter do
  it 'translates the beginning-of-string anchor "\A"' do
    expect(/\A\w/).to\
    become(/^\w/).and keep_matching('abc', with_results: %w[a])
  end

  it 'translates the end-of-string anchor "\z"' do
    expect(/\w\z/).to\
    become(/\w$/).and keep_matching('abc', with_results: %w[c])
  end

  it 'translates the end-of-string-with-optional-newline anchor "\Z"' do
    expect(/\w\Z/).to\
    become(/\w(?=\n?$)/).and keep_matching('abc', with_results: %w[c])
  end

  it 'preserves the beginning-of-line anchor "^"' do
    expect(/^\w/).to stay_the_same.and keep_matching('abc', with_results: %w[a])
  end

  it 'preserves the end-of-line anchor "$"' do
    expect(/\w$/).to stay_the_same.and keep_matching('abc', with_results: %w[c])
  end

  it 'preserves the word-boundary "\b" with a warning' do
    expect(/\w\b/)
      .to stay_the_same
      .with_warning("The boundary '\\b' at index 2 is not unicode-aware in "\
                    'JavaScript, so it might act differently than in Ruby.')
      .and keep_matching('abc', with_results: %w[c])
  end

  it 'preserves the non-word-boundary "\B" with a warning' do
    expect(/\w\B/)
      .to stay_the_same
      .with_warning("The boundary '\\B' at index 2 is not unicode-aware in "\
                    'JavaScript, so it might act differently than in Ruby.')
      .and keep_matching('abc', with_results: %w[a b])
  end

  it 'drops the previous match anchor "\G" with warning' do
    expect(/(.)\G/).to\
    become(/(.)/).with_warning
  end

  it 'drops unknown anchors with warning' do
    expect([:anchor, :an_unknown_anchor]).to be_dropped_with_warning
  end
end
