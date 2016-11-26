# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::Context do
  let(:context) { described_class.new }

  describe '#initialize' do
    it 'sets buffered_set_members to []' do
      expect(context.buffered_set_members).to eq([])
    end

    it 'sets buffered_set_extractions to []' do
      expect(context.buffered_set_extractions).to eq([])
    end

    it 'sets captured_group_count to 0' do
      expect(context.captured_group_count).to eq(0)
    end

    it 'sets group_level to 0' do
      expect(context.send(:group_level)).to eq(0)
    end

    it 'sets negative_set_levels to []' do
      expect(context.send(:negative_set_levels)).to eq([])
    end

    it 'sets set_level to 0' do
      expect(context.send(:set_level)).to eq(0)
    end
  end

  describe '#valid?' do
    it 'is true if we are not in a negative lookbehind' do
      allow(context).to receive(:negative_lookbehind).and_return(false)
      expect(context).to be_valid
    end

    it 'is false if we are in a negative lookbehind' do
      allow(context).to receive(:negative_lookbehind).and_return(true)
      expect(context).not_to be_valid
    end
  end

  describe '#negate_set' do
    it 'adds the current set level to negated set levels once' do
      context.open_set
      context.negate_set
      context.negate_set
      context.open_set
      context.negate_set
      expect(context.send(:negative_set_levels)).to eq([1, 2])
    end
  end

  describe '#close_set' do
    it 'reduces the set level' do
      expect { context.close_set }.to change { context.send(:set_level) }.by(-1)
    end
  end
end
