# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::UnsupportedTokenConverter do
  it 'drops tokens of unknown classes with warning' do
    expect([:unknown_class, :some_subtype]).to be_dropped_with_warning
  end
end
