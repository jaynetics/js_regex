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
        when :name_ref then convert_name_ref
        when :number, :number_ref, :number_rel_ref then convert_to_plain_num_ref
        when :name_call, :number_call, :number_rel_call then convert_call
        else # name_recursion_ref, number_recursion_ref, ...
          warn_of_unsupported_feature
        end
      end

      def convert_name_ref
        # Check if this is a multiplexed named group reference
        if expression.referenced_expressions.count > 1
          convert_multiplexed_name_ref
        else
          # Always use numeric backrefs since we convert all named groups to numbered
          # (see comment in GroupConverter)
          convert_to_plain_num_ref
        end
      end

      def convert_to_plain_num_ref
        position = new_position

        # Check if this backreference refers to a group that was recursively called
        original_group = target_position
        if (recursive_position = context.get_recursive_group_position(original_group))
          # Use the position of the group created by the recursive call
          position = recursive_position
        end

        text = "\\#{position}#{'(?:)' if expression.x?}"
        Node.new(text, reference: position, type: :backref)
      end

      def convert_multiplexed_name_ref
        # Create alternation of all groups with the same name
        positions = expression.referenced_expressions.map do |ref_exp|
          context.new_capturing_group_position(ref_exp.number)
        end

        # Ruby tries groups with the same name from last to first.
        references = positions.reverse.map do |pos|
          Node.new("\\#{pos}", reference: pos, type: :backref)
        end
        Node.new(*references, type: :multiplex_backref)
      end

      def new_position
        context.new_capturing_group_position(target_position)
      end

      def target_position
        expression.referenced_expression.number
      end

      def convert_call
        if context.recursions(expression) >= 5
          warn_of("Recursion for '#{expression}' curtailed at 5 levels")
          return drop
        end

        context.count_recursion(expression)

        context.start_subexp_recursion
        ref = expression.referenced_expression
        result = Converter.for(ref).convert(ref, context, quantified: false)
        context.end_subexp_recursion

        # wrap in passive group if it is a full-pattern recursion
        expression.reference == 0 ? Node.new('(?:', result, ')') : result
      end

    end
  end
end
