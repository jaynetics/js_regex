# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::MetaConverter do
  it 'preserves the dot meta char a.k.a. universal matcher "."' do
    expect(/./).to stay_the_same.and keep_matching(' b%', with_results: [' ', 'b', '%'])
  end

  it 'ensures dots match newlines if the multiline option is set' do
    expect(/a.+a/m).to\
    become(/a(?:.|\n)+a/).and keep_matching('abba', with_results: %w[abba])
  end

  it 'does not make dots match newlines if other options are set' do
    expect(/a.+a/i)
      .to stay_the_same
      .and keep_matching('abba', with_results: ['abba'])
      .and keep_not_matching("ab\nba")
  end

  it 'does not make escaped dots match newlines in multiline mode' do
    expect(/a\.+a/m).to\
    become(/a\.+a/).and keep_matching('aba a.a', with_results: %w[a.a])
  end

  it 'ensures dots match newlines if the multiline option is set via groups' do
    expect(/a(?m:.(?-m:.)).(?m).a/).to\
    become(/a(?:(?:.|\n)(?:.)).(?:.|\n)a/)
      .and keep_matching("abbb\na", with_results: %W[abbb\na])
      .and keep_not_matching("abb\nba")
  end

  it 'does not make dots match newlines if the multiline option is disabled' do
    expect(/a(?-m).(?m).a/m).to\
    become(/a.(?:.|\n)a/)
      .and keep_matching("ab\na", with_results: %W[ab\na])
      .and keep_not_matching("a\nba")
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
    expect(/(a|\X|b)/).to\
    become(/(a|b)/).with_warning
  end

  it 'drops everything if all branches are depleted' do
    expect(/\X|/).to become(//).with_warning
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
