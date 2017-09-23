# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::Context do
  let(:context) { described_class.new(//) }

  describe '#initialize' do
    it 'sets added_capturing_groups_after_group to an empty Hash.new(0)' do
      expect(context
        .instance_variable_get(:@added_capturing_groups_after_group))
        .to eq(Hash.new(0))
    end

    it 'sets capturing_group_count to 0' do
      expect(context.instance_variable_get(:@capturing_group_count)).to eq(0)
    end

    it 'sets named_group_positions to an empty Hash' do
      expect(context.instance_variable_get(:@named_group_positions)).to eq({})
    end

    it 'sets warnings to an empty Array' do
      expect(context.instance_variable_get(:@warnings)).to eq([])
    end
  end
end
