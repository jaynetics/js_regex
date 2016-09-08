
require 'spec_helper'

require File.join('js_regex', 'property_map')

describe 'JsRegex::PROPERTY_MAP' do
  let(:map) { JsRegex::PROPERTY_MAP }

  it 'maps named properties to standard character sets' do
    #
    # All values must be sets, else it won't be as easy to carry
    # negations (as in \p{^alpha} or \P{alpha}) over to JS .
    #
    non_compliant_properties = map.select do |_k, v|
      !v.start_with?('[') || !v.end_with?(']')
    end.keys

    expect(non_compliant_properties).to be_empty
  end

  it 'contains only valid values' do
    #
    # This will find, amongst others, unescaped brackets that will lead to
    # a SyntaxError, invalid ascii escapes, and invalid unicode ranges.
    #
    expect do
      map.values.each { |value| Regexp.new(value) }
    end.not_to raise_error
  end

  it 'does not contain astral plane chars' do
    #
    # Astral plane chars are not supported by JS.
    #
    non_compliant_properties = map.select do |_k, v|
      /\\u\h{5}/ =~ v
    end.keys

    expect(non_compliant_properties).to be_empty
  end

  it 'does not contain duplicate keys' do
    duplicate_keys = map.keys
                        .group_by { |e| e }
                        .select { |_k, v| v.size > 1 }
                        .map(&:first)

    expect(duplicate_keys).to be_empty
  end
end
