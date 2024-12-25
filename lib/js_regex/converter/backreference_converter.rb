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
        if context.es_2018_or_higher?
          # ES 2018+ supports named backrefs, but only the angled-bracket syntax
          Node.new("\\k<#{expression.name}>", reference: new_position, type: :backref)
        else
          convert_to_plain_num_ref
        end
      end

      def convert_to_plain_num_ref
        position = new_position
        text = "\\#{position}#{'(?:)' if expression.x?}"
        Node.new(text, reference: position, type: :backref)
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
        context.increment_local_capturing_group_count
        target_copy = expression.referenced_expression.unquantified_clone
        # avoid "Duplicate capture group name" error in JS
        target_copy.token = :capture if target_copy.is?(:named, :group)
        context.start_subexp_recursion
        result = convert_expression(target_copy)
        context.end_subexp_recursion
        # wrap in group if it is a full-pattern recursion
        expression.reference == 0 ? Node.new('(?:', result, ')') : result
      end
    end
  end
end
