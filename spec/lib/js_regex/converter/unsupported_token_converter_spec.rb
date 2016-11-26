# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::UnsupportedTokenConverter do
  it 'drops tokens of unknown classes with warning' do
    expect_to_drop_token_with_warning(:unknown_class, :some_subtype)
  end

  it 'drops the keep / lookbehind marker "\K" with warning' do
    given_the_ruby_regexp(/a\Kb/)
    expect_js_regex_to_be(/ab/)
    expect_warning
  end
end
