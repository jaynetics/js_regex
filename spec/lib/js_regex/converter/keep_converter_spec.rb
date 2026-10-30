# frozen_string_literal: true

describe JsRegex::Converter::KeepConverter do
  it 'drops the keep mark "\K" with warning', targets: [ES2009, ES2015] do
    expect(/a\Kb/).to\
    become(/ab/).with_warning('ES2018')
  end

  it 'converts root-level keep marks to a lookbehind on ES2018+', targets: [ES2018] do
    expect(/a\Kb/).to\
    become(/(?<=a)b/)
  end

  it 'uses the last keep mark in a sequence', targets: [ES2018] do
    expect(/a\Kb\Kc/).to become(/(?<=ab)c/)
      .and keep_matching('abc', with_results: ['c'])
      .and keep_not_matching('bc', 'ac')
  end

  it 'converts keep marks on every root alternative', targets: [ES2018] do
    expect(/a\Kb|c/).to become(/(?<=a)b|c/)
      .and keep_matching('abc', with_results: %w[b c])
    expect(/c|a\Kb\Kc/).to become(/c|(?<=ab)c/)
      .and keep_matching('abc c', with_results: %w[c c])
    expect(/a\Kb|c\Kd/).to become(/(?<=a)b|(?<=c)d/)
      .and keep_matching('ab cd', with_results: %w[b d])
  end

  it 'drops nested keep marks on ES2018+', targets: [ES2018] do
    # This special case that can't be reproduced with a normal lookbehind
    # because the keep mark works across group boundaries.
    # /a(b\Kc)/ =~ 'abc'; $~ # => #<MatchData "c" 1:"bc">
    expect(/a(b\Kc)d/).to\
    become(/a(bc)d/).with_warning('nested keep mark')
  end
end
