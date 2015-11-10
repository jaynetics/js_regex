class JsRegex
  #
  module Converter
    require_relative 'base'
    #
    # Template class implementation.
    #
    class GroupConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :atomic then open_atomic_group
        when :capture then open_group
        when :close then close_group
        when :comment then '' # drop whole group w/o warning
        when :named_ab, :named_sq then open_named_group
        when :options then open_options_group
        when :passive then open_passive_group
        else open_unsupported_group
        end
      end

      def open_atomic_group
        # Atomicity is emulated using backreferenced lookahead groups:
        # http://instanceof.me/post/52245507631
        # regex-emulate-atomic-grouping-with-lookahead
        context.group_level_for_backreference = context.group_level
        open_group(head: '(?=(')
      end

      def open_named_group
        # drop name w/o warning
        open_group(head: '(')
      end

      def open_options_group
        warn_of_unsupported_feature('group-specific options')
        open_group(head: '(')
      end

      def open_passive_group
        open_group(head: '(?:', non_capturing: true)
      end

      def open_unsupported_group
        warn_of_unsupported_feature
        open_passive_group
      end

      def open_group(options = {})
        context.group_level += 1
        context.captured_group_count += 1 unless options[:non_capturing]
        options[:head] || pass_through
      end

      def close_group
        context.group_level -= 1
        if context.negative_lookbehind
          close_negative_lookbehind
        elsif end_of_atomic_group?
          close_atomic_group
        else
          ')'
        end
      end

      def close_negative_lookbehind
        context.negative_lookbehind = false
        ''
      end

      def end_of_atomic_group?
        return false unless context.group_level_for_backreference
        context.group_level_for_backreference == context.group_level
      end

      def close_atomic_group
        context.group_level_for_backreference = nil
        context.group_count_changed = true
        # the empty passive group (?:) is appended in case literal digits follow
        "))\\#{context.captured_group_count}(?:)"
      end
    end
  end
end
