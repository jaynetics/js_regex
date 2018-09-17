# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::ConditionalConverter do
  # see second_pass_spec.rb for tests of the final results
  it 'marks conditionals for SecondPass conversion' do
    conditional = Regexp::Parser.parse(/(a)(?(1)b|c)/)[1]

    result = JsRegex::Converter.convert(conditional)

    expect(result).to be_a JsRegex::Node
    expect(result.reference).to eq 1
    expect(result.type).to eq :conditional
    expect(result.children[0].to_s).to eq '(?:'
    expect(result.children[1].to_s).to eq '(?:b)'
    expect(result.children[2].to_s).to eq '(?:c)'
    expect(result.children[3].to_s).to eq ')'
  end
end
