# frozen_string_literal: true

class JsRegex
  module Converter
    #
    # Template class. Implement #convert_data in subclasses and return
    # instance of String or Node from it.
    #
    class Base
      # returns instance of Node with #quantifier attached.
      def convert(expression, context)
        self.context    = context
        self.expression = expression

        node = convert_data
        node = Node.new(node) if node.instance_of?(String)
        apply_quantifier(node)
      end

      private

      attr_accessor :context, :expression

      def subtype
        expression.token
      end

      def data
        expression.text
      end
      alias pass_through data

      def apply_quantifier(node)
        return node if node.dropped? || (qtf = expression.quantifier).nil?

        if qtf.possessive?
          node.update(quantifier: qtf.text[0..-2])
          return wrap_in_backrefed_lookahead(node)
        else
          node.update(quantifier: qtf)
        end

        node
      end

      def convert_subexpressions
        Node.new(*expression.map { |subexp| convert_expression(subexp) })
      end

      def convert_expression(expression)
        Converter.convert(expression, context)
      end

      def warn_of_unsupported_feature(description = nil)
        description ||= "#{subtype} #{expression.type}".tr('_', ' ')
        full_desc = "#{description} '#{expression}'"
        warn("Dropped unsupported #{full_desc} at index #{expression.ts}")
        drop
      end

      def warn(text)
        context.warnings << text
      end

      def drop
        Node.new(type: :dropped)
      end
      alias drop_without_warning drop

      def wrap_in_backrefed_lookahead(content)
        backref_num = context.capturing_group_count + 1
        backref_num_node = Node.new(backref_num.to_s, type: :backref_num)
        context.increment_local_capturing_group_count
        # an empty passive group (?:) is appended as literal digits may follow
        Node.new('(?=(', *content, '))\\', backref_num_node, '(?:)')
      end
    end
  end
end
