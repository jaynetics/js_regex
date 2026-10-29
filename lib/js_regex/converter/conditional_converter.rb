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
        target = expression.referenced_expression
        positions = context.get_recursive_group_positions(target.number)
        branches = expression.branches.map { |branch| Node.new('(?:', convert_expression(branch), ')') }
        if positions.length > 1 && Utils::Captures.nonempty?(target)
          references = positions.map { |position| Node.new(reference: position) }
          return Node.new(Node.new(*references), *branches, type: :capture_conditional)
        end

        reference = positions.first || context.new_capturing_group_position(target.number)
        node = Node.new('(?:', reference: reference, type: :conditional)
        branches.each { |branch| node << branch }
        node << ')'
      end
    end
  end
end
