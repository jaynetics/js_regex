# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::Base do
  Ctx = JsRegex::Converter::Context

  context 'in a valid Context' do
    before { allow_any_instance_of(Ctx).to receive(:valid?).and_return(true) }

    it 'appends to the target' do
      expect(JsRegex.new(/abc/).source).to eq('abc')
    end
  end

  context 'in an invalid Context' do
    before { allow_any_instance_of(Ctx).to receive(:valid?).and_return(false) }

    it 'does not append to the target' do
      expect(JsRegex.new(/abc/).source).to eq('')
    end
  end

  describe '#warn_of_unsupported_feature' do
    it 'adds a warning with token class, subtype, data and index' do
      unsupported_regex = JsRegex.new(/(a)\k<1>/)
      expect(unsupported_regex.warnings.first).to eq(
        "Dropped unsupported number ref ab backref '\\k<1>' at index 3...8"
      )
    end

    it 'takes an argument to override the description' do
      converter = described_class.new(
        instance_double(JsRegex, warnings: []), nil
      )
      converter.send(:warn_of_unsupported_feature, 'foobar')
      expect(converter.target.warnings.first)
        .to start_with('Dropped unsupported foobar')
    end
  end
end
