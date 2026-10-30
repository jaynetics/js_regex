# frozen_string_literal: true

describe JsRegex::Converter::ConditionalConverter do
  # See second_pass/alternate_conditional_permutations_spec.rb for expansion details.
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

  it 'drops the condition part without warning' do
    expect(/(a)(?(1)b|c)/).to\
    become(/(?:((?!)a)(?:(?:c)))|(?:(a)(?:(?:b)))/)
  end

  it 'drops unknown conditional expressions with warning' do
    expect([:conditional, :unknown]).to be_dropped_with_warning
  end
end
