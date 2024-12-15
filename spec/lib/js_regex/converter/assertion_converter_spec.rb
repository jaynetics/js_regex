require 'spec_helper'

describe LangRegex::Converter::AssertionConverter do
  it 'preserves positive lookaheads' do
    expect(/a(?=b)/i).to stay_the_same.and keep_matching('aAb', with_results: %w[A])
  end

  it 'preserves negative lookaheads' do
    expect(/a(?!b)/i).to stay_the_same.and keep_matching('aAb', with_results: %w[a])
  end

  it 'makes positive lookbehinds non-lookbehind with warning', targets: [ES2009, ES2015] do
    expect(/(?<=A)b/).to\
    become(/(?:A)b/).with_warning(/lookbehind .*ES2018/)
  end

  it 'drops negative lookbehinds with warning', targets: [ES2009, ES2015] do
    expect(/(?<!A)b/).to\
    become(/b/).with_warning(/negative lookbehind .*ES2018/)
  end

  it 'keeps positive lookbehinds for ES2018+', targets: ES2018 do
    expect(/(?<=A)b/).to stay_the_same
  end

  it 'keeps negative lookbehinds for ES2018+', targets: ES2018 do
    expect(/(?<!A)b/).to stay_the_same
  end

  it 'does not count towards captured groups' do
    expect_any_instance_of(LangRegex::Converter::Context)
      .not_to receive(:capturing_group_count=)
      .with(1)
    LangRegex::JsRegex.new(/a(?=b)/i)
  end
end
