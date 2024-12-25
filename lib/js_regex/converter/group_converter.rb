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
        when :capture then build_group
        when :named then build_named_group
        when :atomic then emulate_atomic_group
        when :comment then drop_without_warning
        when :options, :options_switch then build_options_group
        when :passive then build_passive_group
        when :absence then build_absence_group_if_simple
        else warn_of_unsupported_feature
        end
      end

      def build_named_group
        if context.es_2018_or_higher?
          # ES 2018+ supports named groups, but only the angled-bracket syntax
          build_group(head: "(?<#{expression.name}>")
        else
          build_group
        end
      end

      def emulate_atomic_group
        if context.in_atomic_group
          warn_of_unsupported_feature('nested atomic group')
          build_passive_group
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

      def build_group(opts = {})
        head = opts[:head] || '('
        tail = opts[:tail] || ')'
        return Node.new(*wrap(head, tail)) if opts[:capturing].equal?(false)

        context.capture_group unless context.in_subexp_recursion
        ref = expression.number
        Node.new(*wrap(head, tail), reference: ref, type: :captured_group)
      end

      def wrap(head, tail)
        [head, convert_subexpressions, tail]
      end
    end
  end
end
