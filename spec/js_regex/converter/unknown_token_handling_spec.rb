# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter do
  describe 'unknown token handling' do
    it 'drops tokens of unknown classes with warning' do
      when_parsing_the_token(:unknown_class, :some_subtype)
      expect(@conversion.source).to be_empty
      expect(@conversion.warnings).not_to be_empty
    end

    it 'drops unknown anchors with warning' do
      when_parsing_the_token(:anchor, :an_unknown_anchor)
      expect(@conversion.source).to be_empty
      expect(@conversion.warnings).not_to be_empty
    end

    it 'drops unknown meta elements with warning' do
      when_parsing_the_token(:meta, :an_unknown_meta)
      expect(@conversion.source).to be_empty
      expect(@conversion.warnings).not_to be_empty
    end

    it 'drops unknown types with warning' do
      when_parsing_the_token(:type, :an_unknown_type)
      expect(@conversion.source).to be_empty
      expect(@conversion.warnings).not_to be_empty
    end

    context 'when the token is an unknown group head' do
      it 'opens a regular group with warning' do
        when_parsing_the_token(:group, :an_unknown_group_head)
        expect(@conversion.source).to eq('(')
        expect(@conversion.warnings).not_to be_empty
      end
    end
  end
end

def when_parsing_the_token(token_class, subtype)
  @conversion = JsRegex::Conversion.new(//)
  @conversion.send(:convert_token, token_class, subtype, 'X', 0, 0)
end
