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
                  :captured_group_count,
                  :group_count_changed,
                  :group_level_for_backreference,
                  :negative_lookbehind

      def initialize
        self.buffered_set_members = []
        self.buffered_set_extractions = []
        self.captured_group_count = 0
        self.group_level = 0
        self.negative_set_levels = []
        self.set_level = 0
      end

      def valid?
        !negative_lookbehind
      end

      def stacked_quantifier?(quantifier_start_index, quantifier_end_index)
        is_stacked = last_quantifier_end_index.equal?(quantifier_start_index)
        self.last_quantifier_end_index = quantifier_end_index
        is_stacked
      end

      # set context

      def open_set
        self.set_level = set_level + 1
        if set_level == 1
          buffered_set_members.clear
          buffered_set_extractions.clear
        end
        negative_set_levels.delete(set_level)
      end

      def negate_set
        self.negative_set_levels = negative_set_levels | [set_level]
      end

      def close_set
        self.set_level = set_level - 1
      end

      def set?
        set_level > 0
      end

      def negative_set?(level = set_level)
        negative_set_levels.include?(level)
      end

      def nested_negation?
        nested_set? && negative_set?
      end

      def nested_set?
        set_level > 1
      end

      # group context

      def open_group
        self.group_level = group_level + 1
      end

      def capture_group
        self.captured_group_count = captured_group_count + 1
      end

      def start_atomic_group
        self.group_level_for_backreference = group_level
      end

      def start_negative_lookbehind
        self.negative_lookbehind = true
      end

      def close_group
        self.group_level = group_level - 1
      end

      def close_atomic_group
        close_group
        self.group_level_for_backreference = nil
        self.group_count_changed = true
      end

      def close_negative_lookbehind
        close_group
        self.negative_lookbehind = false
      end

      def atomic_group?
        group_level_for_backreference
      end

      def base_level_of_atomic_group?
        group_level_for_backreference &&
          group_level.equal?(group_level_for_backreference + 1)
      end

      private

      attr_accessor :group_level,
                    :last_quantifier_end_index,
                    :negative_set_levels,
                    :set_level

      attr_writer :buffered_set_extractions,
                  :buffered_set_members,
                  :captured_group_count,
                  :group_count_changed,
                  :group_level_for_backreference,
                  :negative_lookbehind
    end
  end
end
