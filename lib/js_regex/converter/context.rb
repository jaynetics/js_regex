# frozen_string_literal: true

class JsRegex
  module Converter
    #
    # Passed among Converters to globalize basic status data.
    #
    # The Converters themselves are stateless.
    #
    class Context
      attr_reader :buffered_set_extractions,
                  :buffered_set_members,
                  :case_insensitive_root,
                  :in_atomic_group,
                  :named_group_positions,
                  :negative_base_set,
                  :warnings

      def initialize(ruby_regex)
        self.added_capturing_groups_after_group = Hash.new(0)
        self.capturing_group_count = 0
        self.named_group_positions = {}
        self.warnings = []

        self.case_insensitive_root =
          !(ruby_regex.options & Regexp::IGNORECASE).equal?(0)
      end

      # set context

      def negate_base_set
        self.negative_base_set = true
      end

      def reset_set_context
        self.buffered_set_extractions = []
        self.buffered_set_members = []
        self.negative_base_set = false
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

      def wrap_in_backrefed_lookahead(content)
        new_backref_num = capturing_group_count + 1
        # an empty passive group (?:) is appended as literal digits may follow
        result = "(?=(#{content}))\\#{new_backref_num}(?:)"
        added_capturing_groups_after_group[original_capturing_group_count] += 1
        capture_group
        result
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

      def total_added_capturing_groups
        added_capturing_groups_after_group.values.inject(0, &:+)
      end

      def store_named_group_position(name)
        named_group_positions[name] = capturing_group_count + 1
      end

      private

      attr_accessor :added_capturing_groups_after_group,
                    :capturing_group_count

      attr_writer :buffered_set_extractions,
                  :buffered_set_members,
                  :case_insensitive_root,
                  :in_atomic_group,
                  :named_group_positions,
                  :negative_base_set,
                  :warnings
    end
  end
end
