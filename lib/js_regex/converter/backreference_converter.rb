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
        # after regexp_parser update, replace data[/\d+/] with expression.number
        "\\#{context.new_capturing_group_position(data[/\d+/].to_i)}"
      end

      def convert_number_rel_ref
        groups = Array(1..context.original_capturing_group_count)
        absolute_position = groups[expression.number.to_i]
        "\\#{context.new_capturing_group_position(absolute_position)}"
      end

      def convert_name_ref
        "\\#{context.fetch_named_group_position(expression.name)}"
      end
    end
  end
end
