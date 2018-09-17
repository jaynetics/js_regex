# frozen_string_literal: true

class JsRegex
  module Converter
    #
    # Passed among Converters to globalize basic status data.
    #
    # The Converters themselves are stateless.
    #
    class Context
      attr_reader :capturing_group_count,
                  :case_insensitive_root,
                  :in_atomic_group,
                  :named_group_positions,
                  :warnings

      def initialize(case_insensitive_root: false)
        self.added_capturing_groups_after_group = Hash.new(0)
        self.capturing_group_count = 0
        self.named_group_positions = {}
        self.warnings = []

        self.case_insensitive_root = case_insensitive_root
      end

      # group context

      def capture_group
        self.capturing_group_count = capturing_group_count + 1
      end

      def start_atomic_group
        self.in_atomic_group = true
      end

      def end_atomic_group
        self.in_atomic_group = false
      end

      def increment_local_capturing_group_count
        added_capturing_groups_after_group[original_capturing_group_count] += 1
        capture_group
      end

      # takes and returns 1-indexed group positions.
      # new is different from old if capturing groups were added in between.
      def new_capturing_group_position(old_position)
        increment = 0
        added_capturing_groups_after_group.each do |after_n_groups, count|
          increment += count if after_n_groups < old_position
        end
        old_position + increment
      end

      def original_capturing_group_count
        capturing_group_count - total_added_capturing_groups
      end

      def store_named_group_position(name)
        named_group_positions[name] = capturing_group_count + 1
      end

      private

      attr_accessor :added_capturing_groups_after_group

      attr_writer :capturing_group_count,
                  :case_insensitive_root,
                  :in_atomic_group,
                  :named_group_positions,
                  :warnings

      def total_added_capturing_groups
        added_capturing_groups_after_group.values.inject(0, &:+)
      end
    end
  end
end
