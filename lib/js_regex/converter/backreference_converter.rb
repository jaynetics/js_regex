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
        when :name_call           then convert_name_call
        when :number_call         then convert_number_call
        when :number_rel_call     then convert_number_rel_call
        else # name_recursion_ref, number_recursion_ref, ...
          warn_of_unsupported_feature
        end
      end

      def convert_name_ref
        "\\#{context.named_group_positions.fetch(expression.name)}"
      end

      def convert_number_ref
        "\\#{context.new_capturing_group_position(expression.number)}"
      end

      def convert_number_rel_ref
        "\\#{context.new_capturing_group_position(absolute_position)}"
      end

      def absolute_position
        expression.number + context.original_capturing_group_count + 1
      end

      def convert_name_call
        replace_with_group do |group|
          group.token == :named && group.name == expression.name
        end
      end

      def convert_number_call
        if expression.number == 0
          return warn_of_unsupported_feature('whole-pattern recursion')
        end
        replace_with_group do |group|
          [:capture, :options].include?(group.token) &&
            group.number.equal?(expression.number)
        end
      end

      def convert_number_rel_call
        replace_with_group do |group|
          [:capture, :options].include?(group.token) &&
            group.number.equal?(absolute_position)
        end
      end

      def replace_with_group
        context.ast.each_expression do |subexp|
          if subexp.type == :group && yield(subexp)
            return Converter.for(subexp).convert(subexp, context)
          end
        end
        ''
      end
    end
  end
end
