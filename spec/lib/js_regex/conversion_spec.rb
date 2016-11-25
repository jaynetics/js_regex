# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Conversion do
  describe '::of' do
    let(:return_value) { JsRegex::Conversion.of(//) }

    it 'returns an Array' do
      expect(return_value).to be_instance_of(Array)
    end

    it 'includes a source String at index 0' do
      expect(return_value[0]).to be_instance_of(String)
    end

    it 'includes an options String at index 1' do
      expect(return_value[1]).to be_instance_of(String)
    end

    it 'includes a warnings Array at index 2' do
      expect(return_value[2]).to be_instance_of(Array)
    end
  end

  describe '#convert_options' do
    it 'always sets the global flag' do
      given_the_ruby_regexp(//)
      expect(@js_regex.to_h[:options]).to include('g')
    end

    it 'carries over the case-insensitive option' do
      given_the_ruby_regexp(/a/i)
      expect(@js_regex.to_h[:options]).to include('i')
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ABab', with_results: %w(A a))
    end

    it 'does not carry over the multiline option' do
      # this would be bad since JS' multiline option is different from Ruby’s.
      # c.f. meta_converter_spec.rb for option-based token handling.
      given_the_ruby_regexp(//m)
      expect(@js_regex.to_h[:options]).not_to include('m')
      expect_no_warnings
    end

    it 'does not carry over the extended option' do
      # c.f. freespace_converter_spec.rb for option-based token handling.
      given_the_ruby_regexp(//x)
      expect(@js_regex.to_h[:options]).not_to include('x')
      expect_no_warnings
    end
  end

  describe '#perform_sanity_check' do
    context 'when there is a syntax error in the source' do
      let(:bad_conversion) do
        conversion = JsRegex::Conversion.new(/abc/)
        # manually inject illegal source
        conversion.source.replace('[')
        conversion
      end

      it 'sets the source to empty' do
        expect { bad_conversion.send(:perform_sanity_check) }
          .to change { bad_conversion.source }.from('[').to('')
      end

      it 'adds a warning' do
        expect { bad_conversion.send(:perform_sanity_check) }
          .to change { bad_conversion.warnings.count }.by(1)
      end
    end
  end
end
