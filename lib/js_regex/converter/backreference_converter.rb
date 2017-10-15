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
        when :number, :number_ref
          convert_number_ref
        when :number_rel_ref
          convert_number_rel_ref
        when :name_ref
          convert_name_ref
        else
          warn_of_unsupported_feature
        end
      end

      def convert_number_ref
        "\\#{context.new_capturing_group_position(Integer(expression.number))}"
      end

      def convert_number_rel_ref
        absolute_position = Integer(expression.number) +
                            context.original_capturing_group_count + 1
        "\\#{context.new_capturing_group_position(absolute_position)}"
      end

      def convert_name_ref
        "\\#{context.named_group_positions.fetch(expression.name)}"
      end
    end
  end
end
