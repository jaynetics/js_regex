require 'spec_helper'

describe JsRegex::Converter::UnsupportedTokenConverter do
  it 'drops tokens of unknown classes with warning' do
    expect([:unknown_class, :some_subtype]).to be_dropped_with_warning
  end

  it 'drops the keep / lookbehind marker "\K" with warning' do
    expect(/a\Kb/).to\
    become(/ab/).with_warning
  end
end
