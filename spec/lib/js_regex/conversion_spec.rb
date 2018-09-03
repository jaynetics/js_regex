# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Conversion do
  describe '::of' do
    let(:return_value) { described_class.of(/foo/i) }

    it 'returns an Array' do
      expect(return_value).to be_an(Array)
    end

    it 'includes a source String at index 0' do
      expect(return_value[0]).to be_a(String)
    end

    it 'includes an options String at index 1' do
      expect(return_value[1]).to be_a(String)
    end

    it 'includes a warnings Array at index 2' do
      expect(return_value[2]).to be_an(Array)
    end
  end

  describe '#convert_source' do
    it 'passes the regexp to Parser and forwards the output to converters' do
      regexp = //
      tree = expression_double({})
      expect(Regexp::Parser)
        .to receive(:parse)
        .with(regexp)
        .and_return(tree)
      expect_any_instance_of(JsRegex::Converter::RootConverter)
        .to receive(:convert)
        .with(tree, an_instance_of(JsRegex::Converter::Context))
        .and_return(['', []])
      described_class.of(regexp)
    end
  end

  describe '#convert_options' do
    let(:options) { @js_regex.options }

    # all Ruby regexes are what is called "global" in JS
    it 'always sets the global flag' do
      given_the_ruby_regexp(//)
      expect(options).to eq('g')
    end

    it 'carries over the case-insensitive option' do
      given_the_ruby_regexp(/a/i)
      expect(options).to eq('gi')
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ABab', with_results: %w[A a])
    end

    it 'does not carry over the multiline option' do
      # this would be bad since JS' multiline option is different from Ruby's.
      # c.f. meta_converter_spec.rb for option-based token handling.
      given_the_ruby_regexp(//m)
      expect(options).to eq('g')
      expect_no_warnings
    end

    it 'does not carry over the extended option' do
      # c.f. freespace_converter_spec.rb for option-based token handling.
      given_the_ruby_regexp(//x)
      expect(options).to eq('g')
      expect_no_warnings
    end
  end
end
