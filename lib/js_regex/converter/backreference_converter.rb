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

        # Build alternation like (?:\1|\2)
        alternation = positions.map { |pos| "\\#{pos}" }.join('|')
        Node.new("(?:#{alternation})")
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

        # Track groups before the wrapper group is added
        groups_before_wrapper = context.capturing_group_count

        context.increment_local_capturing_group_count
        target_copy = expression.referenced_expression.unquantified_clone
        # avoid "Duplicate capture group name" error in JS
        target_copy.token = :capture if target_copy.is?(:named, :group)
        context.start_subexp_recursion
        result = convert_expression(target_copy)
        context.end_subexp_recursion

        # Track all groups created during this recursive call
        # This handles both the directly called group and any nested groups within it
        # Get all group numbers from the referenced expression
        original_groups = collect_group_numbers(expression.referenced_expression)

        # The first new group number is groups_before_wrapper + 1
        # (the wrapper group from increment_local_capturing_group_count doesn't appear in output)
        first_new_group = groups_before_wrapper + 1

        # Map each original group to its corresponding new group
        # For example, if we recursively called group 1 which contains group 2,
        # and this created groups 3 and 4, then:
        # - group 1 -> group 3
        # - group 2 -> group 4
        original_groups.each_with_index do |old_group_num, index|
          new_group_num = first_new_group + index
          context.track_recursive_group_call(old_group_num, new_group_num)
        end

        # wrap in passive group if it is a full-pattern recursion
        expression.reference == 0 ? Node.new('(?:', result, ')') : result
      end

      def collect_group_numbers(exp)
        return [] if exp.terminal?

        numbers = []
        numbers << exp.number if exp.capturing?
        exp.each_expression { |sub| numbers += collect_group_numbers(sub) }
        numbers
      end
    end
  end
end
