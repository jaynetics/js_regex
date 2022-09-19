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
                  :warnings

      def initialize(case_insensitive_root: false, target: nil)
        self.added_capturing_groups_after_group = Hash.new(0)
        self.capturing_group_count = 0
        self.warnings = []
        self.required_options_hash = {}

        self.case_insensitive_root = case_insensitive_root
        self.target = target
      end

      # target context

      def es_2015_or_higher?
        target >= Target::ES2015
      end

      def es_2018_or_higher?
        target >= Target::ES2018
      end

      # these methods allow appending options to the final Conversion output

      def enable_u_option
        return false unless es_2015_or_higher?

        required_options_hash['u'] = true
      end

      def required_options
        required_options_hash.keys
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

      private

      attr_accessor :added_capturing_groups_after_group,
                    :required_options_hash,
                    :target

      attr_writer :capturing_group_count,
                  :case_insensitive_root,
                  :in_atomic_group,
                  :warnings

      def total_added_capturing_groups
        added_capturing_groups_after_group.values.inject(0, &:+)
      end
    end
  end
end
