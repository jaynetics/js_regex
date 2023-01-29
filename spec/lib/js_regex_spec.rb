require 'spec_helper'

describe JsRegex do
  it 'has a semantic version number' do
    expect(JsRegex::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe '#to_h' do
    let(:return_value) { JsRegex.new(//).to_h }

    it 'returns a Hash' do
      expect(return_value).to be_instance_of(Hash)
    end

    it 'includes a :source String' do
      expect(return_value[:source]).to be_instance_of(String)
    end

    it 'includes an :options String' do
      expect(return_value[:options]).to be_instance_of(String)
    end
  end

  describe '#to_json' do
    let(:return_value) { JsRegex.new(//).to_json }

    it 'returns a String' do
      expect(return_value).to be_instance_of(String)
    end

    it 'encodes the result of #to_h' do
      js_regex = JsRegex.new(/[a-z]+/)
      json = js_regex.to_json
      decoded_json = JSON.parse(json, symbolize_names: true)
      expect(decoded_json).to eq(js_regex.to_h)
    end

    it 'passes on the options parameter, defaulting to {}' do
      expect_any_instance_of(Hash).to receive(:to_json).with(foo: :bar)
      JsRegex.new(//).to_json(foo: :bar)
    end

    it 'passes on an empty hash as options parameter by default' do
      expect_any_instance_of(Hash).to receive(:to_json).with({})
      JsRegex.new(//).to_json
    end
  end

  describe '#to_s' do
    it 'returns a String' do
      expect(JsRegex.new(/foo/).to_s).to eq '/foo/'
    end

    it 'includes options' do
      expect(JsRegex.new(/foo/i).to_s).to eq '/foo/i'
    end

    it 'returns /(?:)/ if the source is empty, as `//` is illegal in JS' do
      expect(JsRegex.new(//).to_s).to eq '/(?:)/'
    end
  end

  describe '#warnings' do
    it 'returns an Array' do
      expect(JsRegex.new(//).warnings).to be_instance_of(Array)
    end
  end

  describe '#target' do
    it 'is the given target' do
      expect(JsRegex.new(//, target: ES2018).target).to eq 'ES2018'
    end

    it 'is ES2009 by default' do
      expect(JsRegex.new(//).target).to eq 'ES2009'
    end
  end

  describe '::new!' do
    it 'returns a JsRegex' do
      expect(JsRegex.new!(//)).to be_a(JsRegex)
    end

    it 'raises if there are incompatibility warnings' do
      expect { JsRegex.new!(/\G/) }.to raise_error(
        JsRegex::ConversionError,
        "unsupported match start anchor '\\G' at index 0"
      )
    end
  end

  describe '::compatible?' do
    it 'returns true for supported regexps' do
      expect(JsRegex.compatible?(//)).to eq true
    end

    it 'raises if there are incompatibility warnings' do
      expect(JsRegex.compatible?(/\G/)).to eq false
    end
  end
end
