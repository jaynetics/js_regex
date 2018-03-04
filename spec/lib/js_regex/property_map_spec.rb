# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

require File.join('js_regex', 'property_map')

describe 'JsRegex::PROPERTY_MAP' do
  MAP = JsRegex::PROPERTY_MAP

  it 'maps named properties to standard character sets' do
    #
    # All values must be sets, else it won't be as easy to carry
    # negations (as in \p{^alpha} or \P{alpha}) over to JS .
    #
    non_compliant_properties = MAP.select do |_k, v|
      !v.start_with?('[') || !v.end_with?(']')
    end.keys

    expect(non_compliant_properties).to be_empty
  end

  it 'covers all BMP properties that are known to Regexp::Scanner' do
    scanner = `gem which regexp_parser`.sub(/\.rb\n\z/, '/scanner.rb')
    known_properties = File.read(scanner).scan(/emit.type, *:(\w+),/).flatten
    expect(known_properties).not_to be_empty

    unhandled_properties = known_properties.reject do |kp|
      kp == 'unknown' ||             # emitted as a fallback, ignore
      kp == 'regional_indicator' ||  # astral plane, ignore
      kp.start_with?('emoji_') ||    # astral plane, ignore
      kp.start_with?('script_') ||   # includes astral plane scripts, ignore
      MAP.key?(kp.to_sym)
    end

    expect(unhandled_properties).to be_empty
  end

  it 'contains only valid values' do
    #
    # This will find, amongst others, unescaped brackets that will lead to
    # a SyntaxError, invalid ascii escapes, and invalid unicode ranges.
    #
    # Ignore that Ruby won't accept surrogate codepoints, though. JS does.
    #
    expect do
      surrogate_codepoint_pattern = /\\uD[89A-F]\h\h/i
      MAP.each_value do |value|
        Regexp.new(value.gsub(surrogate_codepoint_pattern, '.'))
      end
    end.not_to raise_error
  end

  it 'does not contain astral plane chars' do
    #
    # Astral plane chars are not supported by JS.
    #
    non_compliant_properties = MAP.select { |_k, v| /\\u\h{5}/ =~ v }.keys

    expect(non_compliant_properties).to be_empty
  end

  it 'does not contain duplicate keys' do
    duplicate_keys = MAP.keys
                        .group_by { |e| e }
                        .select { |_k, v| v.size > 1 }
                        .map(&:first)

    expect(duplicate_keys).to be_empty
  end
end
