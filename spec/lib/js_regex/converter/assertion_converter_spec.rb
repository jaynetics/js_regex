# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::AssertionConverter do
  it 'preserves positive lookaheads' do
    expect(/a(?=b)/i).to stay_the_same.and keep_matching('aAb', with_results: %w[A])
  end

  it 'preserves negative lookaheads' do
    expect(/a(?!b)/i).to stay_the_same.and keep_matching('aAb', with_results: %w[a])
  end

  it 'makes positive lookbehinds non-lookbehind with warning' do
    expect(/(?<=A)b/).to\
    become(/(?:A)b/).with_warning
  end

  it 'drops negative lookbehinds with warning' do
    expect(/(?<!A)b/).to\
    become(/b/).with_warning('negative lookbehind assertion')
  end

  it 'does not count towards captured groups' do
    expect_any_instance_of(JsRegex::Converter::Context)
      .not_to receive(:capturing_group_count=)
      .with(1)
    JsRegex.new(/a(?=b)/i)
  end
end
