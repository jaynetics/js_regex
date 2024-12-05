require 'spec_helper'

describe LangRegex::Converter::ConditionalConverter do
  # see second_pass_spec.rb for tests of the final results
  it 'marks conditionals for SecondPass conversion' do
    conditional = Regexp::Parser.parse(/(a)(?(1)b|c)/)[1]

    result = LangRegex::JsRegex.js_converter.convert(conditional)

    expect(result).to be_a LangRegex::Node
    expect(result.reference).to eq 1
    expect(result.type).to eq :conditional
    expect(result.children[0].to_s).to eq '(?:'
    expect(result.children[1].to_s).to eq '(?:b)'
    expect(result.children[2].to_s).to eq '(?:c)'
    expect(result.children[3].to_s).to eq ')'
  end

  it 'drops the condition part without warning' do
    expect(/(a)(?(1)b|c)/).to\
    become(/(?:(a){0}(?:(?:b){0}(?:c)))|(?:(a)(?:(?:b)(?:c){0}))/)
  end

  it 'drops unknown conditional expressions with warning' do
    expect([:conditional, :unknown]).to be_dropped_with_warning
  end
end
