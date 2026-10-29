# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class ConditionalConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :open then mark_conditional_for_second_pass
        else warn_of_unsupported_feature
        end
      end

      def mark_conditional_for_second_pass
        reference = context.new_capturing_group_position(expression.referenced_expression.number)
        node = Node.new('(?:', reference: reference, type: :conditional)
        expression.branches.each do |branch|
          node << Node.new('(?:', convert_expression(branch), ')')
        end
        node << ')'
      end
    end
  end
end
