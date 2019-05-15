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
        when :name_ref, :number, :number_ref, :number_rel_ref then convert_ref
        when :name_call, :number_call, :number_rel_call       then convert_call
        else # name_recursion_ref, number_recursion_ref, ...
          warn_of_unsupported_feature
        end
      end

      def convert_ref
        position = context.new_capturing_group_position(target_position)
        Node.new('\\', Node.new(position.to_s, type: :backref_num))
      end

      def target_position
        expression.referenced_expression.number
      end

      def convert_call
        if expression.respond_to?(:number) && expression.number.equal?(0)
          return warn_of_unsupported_feature('whole-pattern recursion')
        end
        context.increment_local_capturing_group_count
        convert_expression(expression.referenced_expression.unquantified_clone)
      end
    end
  end
end
