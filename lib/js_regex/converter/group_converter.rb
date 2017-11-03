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
        when :atomic then emulate_atomic_group
        when :capture then build_group
        when :comment then drop_without_warning
        when :named then build_named_group
        when :options then build_options_group
        when :passive then build_passive_group
        when :absence then warn_of_unsupported_feature
        else build_unsupported_group
        end
      end

      def emulate_atomic_group
        if context.in_atomic_group
          build_unsupported_group('nested atomic group')
        else
          context.start_atomic_group
          result = context.wrap_in_backrefed_lookahead(convert_subexpressions)
          context.end_atomic_group
          result
        end
      end

      def build_named_group
        # remember position, then drop name part without warning
        context.store_named_group_position(expression.name)
        build_group(head: '(')
      end

      def build_options_group
        unless (encoding_options = data.scan(/[adu]/)).empty?
          warn_of_unsupported_feature("encoding options #{encoding_options}")
        end
        # TODO: replace this check in Regexp::Parser v1
        switch_only = !data.include?(':')
        switch_only ? drop_without_warning : build_group(head: '(')
      end

      def build_passive_group
        build_group(head: '(?:', capturing: false)
      end

      def build_unsupported_group(description = nil)
        warn_of_unsupported_feature(description)
        build_passive_group
      end

      def build_group(opts = {})
        context.capture_group unless opts[:capturing].equal?(false)
        head = opts[:head] || pass_through
        "#{head}#{convert_subexpressions})"
      end
    end
  end
end
