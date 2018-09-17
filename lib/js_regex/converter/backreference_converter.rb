# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class BackreferenceConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :name_ref            then convert_name_ref
        when :number, :number_ref then convert_number_ref
        when :number_rel_ref      then convert_number_rel_ref
        when :name_call           then mark_name_call
        when :number_call         then mark_number_call
        when :number_rel_call     then mark_number_rel_call
        else # name_recursion_ref, number_recursion_ref, ...
          warn_of_unsupported_feature
        end
      end

      def convert_name_ref
        convert_ref(context.named_group_positions.fetch(expression.name))
      end

      def convert_number_ref
        convert_ref(context.new_capturing_group_position(expression.number))
      end

      def convert_number_rel_ref
        convert_ref(context.new_capturing_group_position(absolute_position))
      end

      def convert_ref(position)
        Node.new('\\', Node.new(position.to_s, type: :backref_num))
      end

      def absolute_position
        expression.number + context.original_capturing_group_count + 1
      end

      def mark_name_call
        mark_call(expression.name)
      end

      def mark_number_call
        if expression.number.equal?(0)
          return warn_of_unsupported_feature('whole-pattern recursion')
        end
        mark_call(expression.number)
      end

      def mark_number_rel_call
        is_forward_referring = data.include?('+') # e.g. \g<+2>
        mark_call(absolute_position - (is_forward_referring ? 1 : 0))
      end

      def mark_call(reference)
        # increment group count as calls will be substituted with groups
        context.increment_local_capturing_group_count
        Node.new(reference: reference, type: :subexp_call)
      end
    end
  end
end
