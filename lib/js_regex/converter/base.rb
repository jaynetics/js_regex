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
          node.update(quantifier: qtf.dup.tap { |q| q.text = q.text[0..-2] })
          return wrap_in_backrefed_lookahead(node)
        elsif qtf.token == :interval && qtf.text[0..1] == "{,"
          node.update(quantifier: qtf.dup.tap { |q| q.text = "{0,#{q.max}}" })
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

      def warn_of_unsupported_feature(description = nil, min_target: nil)
        description ||= "#{subtype} #{expression.type}".tr('_', ' ')
        full_text = "Dropped unsupported #{description} '#{expression}' "\
                    "at index #{expression.ts}"
        if min_target
          full_text += " (requires at least `target: '#{min_target}'`)"
        end
        warn_of(full_text)
        drop
      end

      def warn_of(text)
        if context.fail_fast
          raise ConversionError, text.sub(/^Dropped /, '')
        else
          context.warnings << text
        end
      end

      def drop
        Node.new(type: :dropped)
      end
      alias drop_without_warning drop

      def wrap_in_backrefed_lookahead(content)
        number = context.capturing_group_count + 1
        backref_node = Node.new("\\#{number}", reference: number, type: :backref)
        context.increment_local_capturing_group_count
        # The surrounding group is added so that quantifiers apply to the whole.
        # Without it, `(?:)` would need to be appended as literal digits may follow.
        Node.new('(?:(?=(', *content, '))', backref_node, ')')
      end
    end
  end
end
