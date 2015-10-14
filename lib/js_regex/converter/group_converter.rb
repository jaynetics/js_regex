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
        when :capture, :passive then open_group
        when :close then close_group
        when :comment then '' # drop whole group w/o warning
        when :named_ab, :named_sq then open_group('(') # drop name w/o warning
        when :options then open_options_group
        else
          warn_of_unsupported_feature
          open_group('(')
        end
      end

      def open_atomic_group
        # Atomicity is achieved with backreferenced lookahead groups:
        # http://instanceof.me/post/52245507631
        # regex-emulate-atomic-grouping-with-lookahead
        context.group_level_for_backreference = context.group_level
        context.group_number_for_backreference = context.opened_groups + 1
        open_assertion('(?=(')
      end

      def open_options_group
        warn_of_unsupported_feature('group-specific options')
        open_group('(')
      end

      def open_group(group_head = pass_through)
        context.group_level += 1
        context.opened_groups += 1
        group_head
      end

      def open_assertion(assertion_head = pass_through)
        # these don't count as opened groups for backreference purposes
        context.group_level += 1
        assertion_head
      end

      def close_group
        if context.negative_lookbehind
          close_negative_lookbehind
        else
          context.group_level -= 1
          if end_of_atomic_group?
            close_atomic_group
          else
            ')'
          end
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
        # an empty passive group is appended in case literal digits follow
        "))\\#{context.group_number_for_backreference}(?:)"
      end
    end
  end
end
