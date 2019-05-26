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
        when :capture, :named then build_group
        when :atomic then emulate_atomic_group
        when :comment then drop_without_warning
        when :options, :options_switch then build_options_group
        when :passive then build_passive_group
        when :absence then build_absence_group_if_simple
        else build_unsupported_group
        end
      end

      def emulate_atomic_group
        if context.in_atomic_group
          build_unsupported_group('nested atomic group')
        else
          context.start_atomic_group
          result = wrap_in_backrefed_lookahead(convert_subexpressions)
          context.end_atomic_group
          result
        end
      end

      def build_options_group
        if subtype.equal?(:options_switch)
          # can be ignored since #options on subsequent Expressions are correct
          drop_without_warning
        else
          build_passive_group
        end
      end

      def build_passive_group
        build_group(head: '(?:', capturing: false)
      end

      def build_absence_group_if_simple
        if unmatchable_absence_group?
          unmatchable_substitution
        elsif expression.inner_match_length.fixed?
          build_absence_group
        else
          warn_of_unsupported_feature('variable-length absence group content')
        end
      end

      def unmatchable_absence_group?
        expression.empty?
      end

      def unmatchable_substitution
        '(?!)'
      end

      def build_absence_group
        head = "(?:(?:.|\\n){,#{expression.inner_match_length.min - 1}}|(?:(?!"
        tail = ')(?:.|\n))*)'
        build_group(head: head, tail: tail, capturing: false)
      end

      def build_unsupported_group(description = nil)
        warn_of_unsupported_feature(description)
        build_passive_group
      end

      def build_group(opts = {})
        head = opts[:head] || '('
        tail = opts[:tail] || ')'
        return Node.new(*wrap(head, tail)) if opts[:capturing].equal?(false)

        context.capture_group
        ref = expression.number
        Node.new(*wrap(head, tail), reference: ref, type: :captured_group)
      end

      def wrap(head, tail)
        [head, convert_subexpressions, tail]
      end
    end
  end
end
