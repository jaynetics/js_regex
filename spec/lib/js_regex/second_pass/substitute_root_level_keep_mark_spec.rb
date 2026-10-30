# frozen_string_literal: true

describe JsRegex::SecondPass::SubstituteRootLevelKeepMark, targets: [ES2018] do
  before { stub_const('JsRegex::SecondPass::STEPS', [described_class]) }

  it 'leaves trees without keep marks unchanged' do
    expect(/abc/).to stay_the_same
  end

  it 'replaces a keep mark with a lookbehind' do
    expect(/a\Kb/).to become('(?<=a)b')
  end

  it 'uses the last keep mark in a sequence' do
    expect(/a\Kb\Kc/).to become('(?<=ab)c')
      .and keep_matching('abc', with_results: ['c'])
  end

  it 'keeps root alternatives outside the lookbehind' do
    expect(/a\Kb|c\Kd/).to become('(?<=a)b|(?<=c)d')
      .and keep_matching('ab', 'cd')
      .and keep_not_matching('a', 'c')
  end
end
