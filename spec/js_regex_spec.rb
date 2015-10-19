
require 'spec_helper'

describe JsRegex do
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

    it "can be used with JavaScript's new RegExp() constructor" do
      given_the_ruby_regexp(/[a-z]+/)
      matches = matches_in_javascript_using_to_json_result_on('abc123')
      expect(matches).to eq(%w(abc))
    end
  end

  describe '#to_s' do
    let(:return_value) { JsRegex.new(//).to_s }

    it 'returns a String' do
      expect(return_value).to be_instance_of(String)
    end

    it 'can be injected directly into JS' do
      given_the_ruby_regexp(/[a-z]+/)
      matches = matches_in_javascript_using_to_s_result_on('abc123')
      expect(matches).to eq(%w(abc))
    end
  end

  describe '#warnings' do
    let(:return_value) { JsRegex.new(//).warnings }

    it 'returns an Array' do
      expect(return_value).to be_instance_of(Array)
    end
  end
end
