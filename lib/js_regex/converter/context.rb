class JsRegex
  module Converter
    #
    # Passed among Converters to globalize basic status data.
    #
    # The Converters themselves are stateless.
    #
    class Context
      attr_accessor :buffered_set_members,
                    :buffered_set_extractions,
                    :captured_group_count,
                    :group_count_changed,
                    :group_level,
                    :group_level_for_backreference,
                    :negative_lookbehind,
                    :negative_set_levels,
                    :previous_quantifier_subtype,
                    :previous_quantifier_end,
                    :set_level

      def initialize
        self.buffered_set_members = []
        self.buffered_set_extractions = []
        self.captured_group_count = 0
        self.group_count_changed = false
        self.group_level = 0
        self.negative_lookbehind = false
        self.negative_set_levels = []
        self.set_level = 0
      end

      def valid?
        !negative_lookbehind
      end

      # set context

      def open_set
        self.set_level += 1
        if set_level == 1
          buffered_set_members.clear
          buffered_set_extractions.clear
        end
        self.negative_set_levels -= [set_level]
      end

      def negate_set
        self.negative_set_levels |= [set_level]
      end

      def negative_set?(level = set_level)
        negative_set_levels.include?(level)
      end

      def nested_negation?
        set_level > 1 && negative_set?
      end

      def close_set
        self.set_level -= 1
      end
    end
  end
end
