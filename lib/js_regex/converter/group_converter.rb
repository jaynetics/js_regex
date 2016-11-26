# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
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
        when :comment then '' # drop whole group without warning
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
        if context.atomic_group?
          open_unsupported_group('nested atomic group')
        else
          context.start_atomic_group
          open_group(head: '(?=(')
        end
      end

      def open_named_group
        # drop name without warning
        open_group(head: '(')
      end

      def open_options_group
        warn_of_unsupported_feature('group-specific options')
        open_group(head: '(')
      end

      def open_passive_group
        open_group(head: '(?:', capturing: false)
      end

      def open_unsupported_group(description = nil)
        warn_of_unsupported_feature(description)
        open_passive_group
      end

      def open_group(opts = {})
        context.open_group
        context.capture_group unless opts[:capturing].equal?(false)
        opts[:head] || pass_through
      end

      def close_group
        if context.negative_lookbehind
          context.close_negative_lookbehind
          ''
        elsif context.base_level_of_atomic_group?
          context.close_atomic_group
          # an empty passive group (?:) is appended as literal digits may follow
          "))\\#{context.captured_group_count}(?:)"
        else
          context.close_group
          ')'
        end
      end
    end
  end
end
