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
                  :in_atomic_group,
                  :negative_base_set,
                  :root_options

      def initialize(ruby_regex)
        self.captured_group_count = 0

        self.root_options = {}
        root_options[:m] = (ruby_regex.options & Regexp::MULTILINE).nonzero?
      end

      # option context

      def multiline?
        root_options[:m]
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
        self.captured_group_count = captured_group_count + 1
      end

      def start_atomic_group
        self.in_atomic_group = true
      end

      def end_atomic_group
        self.in_atomic_group = false
        self.group_count_changed = true
      end

      private

      attr_writer :buffered_set_extractions,
                  :buffered_set_members,
                  :captured_group_count,
                  :group_count_changed,
                  :in_atomic_group,
                  :negative_base_set,
                  :root_options
    end
  end
end
