# frozen_string_literal: true

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
    expect(/abc\Z/).to\
    become(/abc(?=\n?$)/)
      .and keep_matching('abc', "abc\n")
      .and keep_not_matching('abcdef', "abc\n\n")
  end

  it 'preserves the beginning-of-line anchor "^"', targets: [ES2009, ES2015] do
    expect(/^\w/).to stay_the_same.and keep_matching('abc', with_results: %w[a])
  end

  it 'converts the beginning-of-line anchor "^"', targets: [ES2018] do
    expect(/^\w?/).to\
    become('(?<=^|\n(?!$))\w?')
      .and keep_matching("a\nb", with_results: %w[a b])
  end

  it 'converts the end-of-line anchor "$"' do
    expect(/\w$/).to\
    become(/\w(?=$|\n)/)
      .and keep_matching("a\nbc", with_results: %w[a c])
  end

  it 'preserves the word-boundary anchor "\b" with a warning', targets: [ES2009, ES2015] do
    expect(/\w\b/)
      .to stay_the_same
      .with_warning("The anchor '\\b' at index 2 only works at ASCII word boundaries")
      .and keep_matching('abc', with_results: %w[c])
  end

  it 'uses a unicode-awary replacement for "\b" on ES2018+', targets: [ES2018] do
    expect(/\w\b/).to\
    become('\w(?:(?<=[\p{N}\p{L}\p{M}\p{Pc}])(?=[^\p{N}\p{L}\p{M}\p{Pc}]|$)'\
           '|(?<=[^\p{N}\p{L}\p{M}\p{Pc}]|^)(?=[\p{N}\p{L}\p{M}\p{Pc}]))')
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
    become('\\w(?:(?<=[\\p{N}\\p{L}\\p{M}\\p{Pc}])(?=[\\p{N}\\p{L}\\p{M}\\p{Pc}])'\
           '|(?<=[^\\p{N}\\p{L}\\p{M}\\p{Pc}]|^)(?=[^\\p{N}\\p{L}\\p{M}\\p{Pc}]|$))')
      .with_options('u')
      .and keep_matching('abc tür', with_results: %w[a b t])
      # ^ this is correct; both in Ruby and JS, \w is is ascii-only by default
  end

  it 'matches non-boundaries between nonword characters and string edges', targets: [ES2018] do
    expect(/\B/).to keep_matching('', '!', '!!', ' ')
      .and keep_not_matching('a')
    expect(/\A\B!\B\z/).to keep_matching('!')
      .and keep_not_matching('a', '!!')
    expect(/!\B!/).to keep_matching('!!')
      .and keep_not_matching('!a!')
  end

  it 'treats Unicode numbers as word characters at boundaries', targets: [ES2018] do
    %w[١ ９ 𝟡 Ⅻ ½].each do |char|
      expect(/\A\b#{char}\b\z/).to keep_matching(char)
      expect(/\A\B#{char}\z/).to keep_not_matching(char)
      expect(/#{char}\B#{char}/).to keep_matching(char * 2)
    end
  end

  it 'drops the previous match anchor "\G" with warning' do
    expect(/(foo)\G/).to\
    become(/(foo)/).with_warning
  end

  it 'drops unknown anchors with warning' do
    expect([:anchor, :an_unknown_anchor]).to be_dropped_with_warning
  end
end
