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

    it 'also works if called with a source String instead of a Regexp' do
      expect(described_class.of('foo')).to be_an(Array)
    end
  end

  describe '#convert_source' do
    it 'passes the regexp to Parser and forwards the output to converters' do
      regexp = //
      tree = expression_double({i?: false})
      expect(Regexp::Parser)
        .to receive(:parse)
        .with(regexp)
        .and_return(tree)
      expect(JsRegex::Converter)
        .to receive(:convert)
        .with(tree, an_instance_of(JsRegex::Converter::Context))
        .and_return(JsRegex::Node.new(''))
      described_class.of(regexp)
    end

    it 'sets Context#case_insensitive_root to true if the regex has the i-flag' do
      expect(JsRegex::Converter::Context)
        .to receive(:new).with(case_insensitive_root: true)
        .and_call_original
      described_class.of(//i)
    end

    it 'sets Context#case_insensitive_root to false if the regex has no i-flag' do
      expect(JsRegex::Converter::Context)
        .to receive(:new).with(case_insensitive_root: false)
        .and_call_original
      described_class.of(//m)
    end

    it 'raises TypeError for Node#to_s on nodes with SecondPass processing' do
      expect { JsRegex::Node.new(type: :conditional).to_s }.to raise_error(
        TypeError, 'conditional must be substituted before stringification'
      )
    end
  end

  describe '#convert_options' do
    it 'includes the options g, i, m, u, y if forced' do
      expect(JsRegex.new(/a/, options: 'g').options).to     eq('g')
      expect(JsRegex.new(/a/, options: 'i').options).to     eq('i')
      expect(JsRegex.new(/a/, options: 'gimuy').options).to eq('gimuy')
      expect(JsRegex.new(/a/, options: %w[g m]).options).to eq('gm')
    end

    it 'cannot be forced to include other options' do
      expect(JsRegex.new(/a/, options: 'f').options).to     eq('')
      expect(JsRegex.new(/a/, options: 'fLüYz').options).to eq('')
      expect(JsRegex.new(/a/, options: '').options).to      eq('')
      expect(JsRegex.new(/a/, options: []).options).to      eq('')
    end

    it 'carries over the case-insensitive option' do
      expect(JsRegex.new(/a/i).options).to eq('i')
    end

    it 'does not carry over the multiline option' do
      # this would be bad since JS' multiline option is different from Ruby's.
      # c.f. meta_converter_spec.rb for option-based token handling.
      expect(JsRegex.new(/a/m).options).to eq('')
    end

    it 'does not carry over the extended option' do
      # c.f. freespace_converter_spec.rb for option-based token handling.
      expect(JsRegex.new(/a/x).options).to eq('')
    end

    it 'includes only forced options if passed a source String' do
      expect(JsRegex.new('a').options).to               eq('')
      expect(JsRegex.new('a', options: 'g').options).to eq('g')
    end
  end
end
