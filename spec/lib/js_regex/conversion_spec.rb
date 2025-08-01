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

    it 'raises an ArgumentError for unknown targets' do
      expect { described_class.of('foo', target: 'ES3000') }
        .to raise_error(ArgumentError)
    end
  end

  describe '#convert_source' do
    it 'sets Context#case_insensitive_root to true if the regex has the i-flag' do
      expect_any_instance_of(JsRegex::Converter::Context)
        .to receive(:case_insensitive_root=).with(true)
      described_class.of(//i)
    end

    it 'sets Context#case_insensitive_root to false if the regex has no i-flag' do
      expect_any_instance_of(JsRegex::Converter::Context)
        .to receive(:case_insensitive_root=).with(false)
      described_class.of(//m)
    end

    it 'raises if the Parser fails' do
      expect { described_class.of('(') }.to raise_error(JsRegex::Error, /group/)
    end

    it 'raises for Node#to_s on nodes without SecondPass processing' do
      expect { JsRegex::Node.new(type: :conditional).to_s }.to raise_error(
        JsRegex::Error, 'conditional must be substituted before stringification'
      )
    end
  end

  describe '#convert_options' do
    it 'includes the options g, i, m, s, u, y if forced' do
      expect(JsRegex.new(/a/, options: 'g').options).to      eq('g')
      expect(JsRegex.new(/a/, options: 'i').options).to      eq('i')
      expect(JsRegex.new(/a/, options: 'gimsuy').options).to eq('gimsuy')
      expect(JsRegex.new(/a/, options: %w[g m]).options).to  eq('gm')
    end

    it 'cannot be forced to include other options' do
      expect(JsRegex.new(/a/, options: 'f').options).to      eq('')
      expect(JsRegex.new(/a/, options: 'fLüYz').options).to  eq('')
      expect(JsRegex.new(/a/, options: '').options).to       eq('')
      expect(JsRegex.new(/a/, options: []).options).to       eq('')
    end

    it 'carries over the case-insensitive option' do
      expect(JsRegex.new(/a/i).options).to eq('i')
    end

    it 'does not carry over the multiline option' do
      # This would be bad since JS' multiline and dot-all options are both
      # different from Ruby's "multiline" option.
      # C.f. meta_converter_spec.rb for option-based token handling.
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
