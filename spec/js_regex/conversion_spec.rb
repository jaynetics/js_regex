
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
end
