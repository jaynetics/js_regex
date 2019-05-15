# frozen_string_literal: true

require 'spec_helper'

describe JsRegex do
  describe '#to_h' do
    let(:return_value) { described_class.new(//).to_h }

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
    let(:return_value) { described_class.new(//).to_json }

    it 'returns a String' do
      expect(return_value).to be_instance_of(String)
    end

    it 'encodes the result of #to_h' do
      js_regex = described_class.new(/[a-z]+/)
      json = js_regex.to_json
      decoded_json = JSON.parse(json, symbolize_names: true)
      expect(decoded_json).to eq(js_regex.to_h)
    end

    it 'passes on the options parameter, defaulting to {}' do
      Hash.send(:define_method, :to_json) { |options| options }
      expect(described_class.new(//).to_json(foo: :bar)).to eq(foo: :bar)
    end

    it 'passes on an empty hash as options parameter by default' do
      Hash.send(:define_method, :to_json) { |options| options }
      expect(described_class.new(//).to_json).to eq({})
    end
  end

  describe '#to_s' do
    it 'returns a String' do
      expect(described_class.new(/foo/).to_s).to eq '/foo/'
    end

    it 'includes options' do
      expect(described_class.new(/foo/i).to_s).to eq '/foo/i'
    end

    it 'returns /(?:)/ if the source is empty, as `//` is illegal in JS' do
      expect(described_class.new(//).to_s).to eq '/(?:)/'
    end
  end

  describe '#warnings' do
    it 'returns an Array' do
      expect(described_class.new(//).warnings).to be_instance_of(Array)
    end
  end
end
