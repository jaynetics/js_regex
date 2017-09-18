# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::Context do
  let(:context) { described_class.new(//) }

  describe '#initialize' do
    it 'sets captured_group_count to 0' do
      expect(context.captured_group_count).to eq(0)
    end
  end
end
