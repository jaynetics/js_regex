require 'spec_helper'

describe LangRegex::Converter::Context do
  let(:context) { described_class.new }

  describe '#initialize' do
    it 'sets added_capturing_groups_after_group to empty Hash with default 0' do
      hash = context.send(:added_capturing_groups_after_group)
      expect(hash).to be_a(Hash)
      expect(hash[99]).to eq(0)
    end

    it 'sets capturing_group_count to 0' do
      expect(context.send(:capturing_group_count)).to eq(0)
    end

    it 'sets warnings to an empty Array' do
      expect(context.send(:warnings)).to eq([])
    end

    it 'sets #case_insensitive_root to true if passed true' do
      context = described_class.new(case_insensitive_root: true)
      expect(context.case_insensitive_root).to be true
    end

    it 'sets #case_insensitive_root to false if passed false' do
      context = described_class.new(case_insensitive_root: false)
      expect(context.case_insensitive_root).to be false
    end

    it 'defaults to #case_insensitive_root == false' do
      context = described_class.new
      expect(context.case_insensitive_root).to be false
    end
  end

  # group context

  describe '#capture_group' do
    it 'increases capturing_group_count' do
      7.times { context.capture_group }
      expect(context.send(:capturing_group_count)).to eq 7
    end
  end

  describe '#start_atomic_group' do
    it 'sets in_atomic_group to true' do
      context.instance_variable_set(:@in_atomic_group, false)
      context.start_atomic_group
      expect(context.in_atomic_group).to be true
    end
  end

  describe '#end_atomic_group' do
    it 'sets in_atomic_group to false' do
      context.instance_variable_set(:@in_atomic_group, true)
      context.end_atomic_group
      expect(context.in_atomic_group).to be false
    end
  end

  describe '#increment_local_capturing_group_count' do
    it 'adds to added_capturing_groups_after_group based on current position' do
      context.capture_group
      context.increment_local_capturing_group_count
      context.capture_group
      context.increment_local_capturing_group_count
      context.increment_local_capturing_group_count
      expect(context.send(:added_capturing_groups_after_group))
        .to eq(1 => 1, 2 => 2)
    end
  end

  describe '#new_capturing_group_position' do
    it 'increments the passed position by count of groups added before it' do
      allow(context).to receive(:added_capturing_groups_after_group)
        .and_return(1 => 100, 2 => 100, 3 => 100, 4 => 100, 5 => 100)
      expect(context.new_capturing_group_position(4)).to eq(304)
    end

    it 'returns the original value if no groups have been added' do
      allow(context).to receive(:added_capturing_groups_after_group)
        .and_return({})
      expect(context.new_capturing_group_position(4)).to eq(4)
    end
  end

  describe '#original_capturing_group_count' do
    it 'returns the current capturing group count minus added ones' do
      allow(context).to receive(:capturing_group_count).and_return(100)
      allow(context).to receive(:total_added_capturing_groups).and_return(10)
      expect(context.original_capturing_group_count).to eq(90)
    end
  end

  describe '#total_added_capturing_groups' do
    it 'returns the sum of all added capturing groups' do
      allow(context).to receive(:added_capturing_groups_after_group)
        .and_return(1 => 100, 2 => 100, 3 => 100, 4 => 100, 5 => 100)
      expect(context.send(:total_added_capturing_groups)).to eq(500)
    end

    it 'returns 0 if no groups have been added' do
      allow(context).to receive(:added_capturing_groups_after_group)
        .and_return({})
      expect(context.send(:total_added_capturing_groups)).to eq(0)
    end
  end
end
