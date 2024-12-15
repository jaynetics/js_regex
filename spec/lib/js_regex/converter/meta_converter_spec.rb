require 'spec_helper'

describe LangRegex::Converter::MetaConverter do
  it 'replaces the dot meta char so that it keeps matching astral stuff, too' do
    expect(/a.a/).to\
    become('a(?:[\uD800-\uDBFF][\uDC00-\uDFFF]|[^\n\uD800-\uDFFF])a')
      .and keep_matching('aba', 'aüa', 'a😋a', "a\ra")
      .and keep_not_matching("a\na")
  end

  it 'ensures dots match newlines if the multiline option is set' do
    expect(/a.a/m).to\
    become('a(?:[\uD800-\uDBFF][\uDC00-\uDFFF]|[^\uD800-\uDFFF])a')
      .and keep_matching('aba', 'aüa', 'a😋a', "a\ra", "a\na")
  end

  it 'preserves the alternation meta char "|"' do
    expect(/a|b/).to stay_the_same.and keep_matching('a b', with_results: %w[a b])
  end

  it 'preserves recursive alternations' do
    expect(/a|(b|c)/).to stay_the_same.and keep_matching('c', with_results: %w[c])
  end

  it 'applies further conversions to alternation branches' do
    expect(/(b\G|c)/).to\
    become(/(b|c)/).with_warning
  end

  it 'drops depleted alternation branches' do
    expect(/(a|\G|b)/).to\
    become(/(a|b)/).with_warning
  end

  it 'drops everything if all branches are depleted' do
    expect(/\G|/).to become(//).with_warning
  end

  it 'does not drop alternation branches that started out empty' do
    expect(/(|ccc)/).to stay_the_same
  end

  it 'does not drop alternation branches containing supported calls' do
    expect(/(a)(\g<1>|ccc)/).to\
    become(/(a)((a)|ccc)/)
  end

  it 'does not drop alternation branches containing empty groups' do
    expect(/((()|())|()+|ccc)/).to stay_the_same
  end

  it 'drops unknown meta elements with warning' do
    expect([:meta, :an_unknown_meta]).to be_dropped_with_warning
  end
end
