require 'spec_helper'

describe LangRegex::Converter::UnsupportedTokenConverter do
  it 'drops tokens of unknown classes with warning' do
    expect([:unknown_class, :some_subtype]).to be_dropped_with_warning
  end
end
