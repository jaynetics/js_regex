# frozen_string_literal: true

class JsRegex
  module Converter
    #
    # Template class. Implement #convert_data in subclasses.
    #
    class Base
      def convert(expression, context)
        self.context    = context
        self.expression = expression

        source = convert_data
        apply_quantifier(source)
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

      def apply_quantifier(source)
        return source if source.empty? || !(quantifier = expression.quantifier)

        if quantifier.mode.equal?(:possessive)
          context.wrap_in_backrefed_lookahead(source + quantifier.text[0..-2])
        else
          source + quantifier
        end
      end

      def convert_subexpressions
        convert_expressions(subexpressions)
      end

      def convert_expressions(expressions)
        expressions.map { |exp| Converter.for(exp).convert(exp, context) }.join
      end

      def subexpressions
        expression.expressions
      end

      def warn_of_unsupported_feature(description = nil)
        description ||= "#{subtype} #{expression.type}".tr('_', ' ')
        full_desc = "#{description} '#{expression}'"
        warn("Dropped unsupported #{full_desc} at index #{expression.ts}")
        ''
      end

      def warn(text)
        context.warnings << text
      end

      def drop_without_warning
        ''
      end
    end
  end
end
