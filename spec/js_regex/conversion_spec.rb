
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

  describe '#perform_sanity_check' do
    context 'when there is a syntax error in the source' do
      let(:bad_conversion) do
        conv = JsRegex::Conversion.new(/abc/)
        # manually inject illegal source
        conv.instance_variable_set('@source', '[')
        conv
      end

      it 'sets the source to empty' do
        bad_conversion.send(:perform_sanity_check)
        source = bad_conversion.instance_variable_get('@source')
        expect(source).to be_empty
      end

      it 'adds a warning' do
        bad_conversion.send(:perform_sanity_check)
        warnings = bad_conversion.instance_variable_get('@warnings')
        expect(warnings).not_to be_empty
      end
    end
  end
end
