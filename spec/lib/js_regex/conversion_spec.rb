
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
