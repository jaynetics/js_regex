# frozen_string_literal: true

require_relative '../node'
require_relative '../utils'

class JsRegex
  module Converter
    #
    # Template class. Implement #convert_data in subclasses and return
    # instance of String or Node from it.
    #
    class Base
      # returns instance of Node with #quantifier attached.
      def convert(expression, context, quantified: true)
        self.context    = context
        self.expression = expression

        if quantified && expression.quantifier && expression.quantifier.possessive?
          wrap_in_backrefed_lookahead { convert_node(quantified) }
        else
          convert_node(quantified)
        end
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

      def convert_node(quantified)
        node = convert_data
        node = Node.new(node) if node.instance_of?(String)
        quantified ? apply_quantifier(node) : node
      end

      def apply_quantifier(node)
        return node if node.dropped? || (qtf = expression.quantifier).nil?

        if qtf.possessive?
          node.update(quantifier: qtf.dup.tap { |q| q.text = q.text[0..-2] })
        elsif qtf.token == :interval && qtf.text[0..1] == "{,"
          node.update(quantifier: qtf.dup.tap { |q| q.text = "{0,#{q.max}}" })
        else
          node.update(quantifier: qtf)
        end

        node
      end

      def convert_subexpressions
        # mark alternation and conditional branches for processing in second pass
        type = expression.is?(:sequence) ? :branch : :plain
        Node.new(*expression.map { |subexp| convert_expression(subexp) }, type: type)
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

      def wrap_in_backrefed_lookahead
        number = context.capture_group(added: true)
        content = yield
        if content.is_a?(Node) && content.dropped?
          context.cancel_added_capturing_group
          return content
        end
        backref_node = Node.new("\\#{number}", reference: number, type: :backref)
        backrefed_group = Node.new('(', *content, ')', reference: number, type: :captured_group)
        # The surrounding group is added so that quantifiers apply to the whole.
        # Without it, `(?:)` would need to be appended as literal digits may follow.
        Node.new('(?:(?=', backrefed_group, ')', backref_node, ')')
      end

      def unmatchable_substitution
        '(?!)'
      end
    end
  end
end
