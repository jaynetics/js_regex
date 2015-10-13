
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

    it 'duplicates escape characters' do
      # If you want to use 'new RegExp()' in JS to match, say, 'a\b',
      # then you you have to type new RegExp('a\\\\b'), in all seriousness.
      expect(JsRegex.new(/a\\b/).to_h[:source]).to eq('a\\\\\\\\b')
    end

    it "can be used in 'new RegExp()' in JS" do
      given_the_ruby_regexp(/a\\b/)
      when_using_to_h_and_new_regexp_in_js_to_match('a\b')
      expect_new_regexp_match_results_to_be(['a\b'])
    end
  end

  describe '#to_s' do
    let(:return_value) { JsRegex.new(//).to_s }

    it 'returns a String' do
      expect(return_value).to be_instance_of(String)
    end

    it 'can be injected directly into JS' do
      given_the_ruby_regexp(/a\\b/)
      expect(@js_regex.to_s).to start_with('/a\\\\b/')
      expect(matches_in_javascript_on('a\b')).to eq(['a\b'])
    end
  end

  describe '#warnings' do
    let(:return_value) { JsRegex.new(//).warnings }

    it 'returns an Array' do
      expect(return_value).to be_instance_of(Array)
    end
  end
end
