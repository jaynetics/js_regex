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
        self.warnings   = []

        source = convert_data
        source_with_quantifier = apply_quantifier(source)
        [source_with_quantifier, warnings]
      end

      private

      attr_accessor :context, :expression, :warnings

      def subtype
        expression.token
      end

      def data
        expression.text
      end
      alias pass_through data

      def apply_quantifier(source)
        return source unless (quantifier = expression.quantifier)

        if quantifier.mode == :possessive
          # an empty passive group (?:) is appended as literal digits may follow
          backref_num = context.captured_group_count + 1
          "(?=(#{source}#{quantifier.text[0..-2]}))\\#{backref_num}(?:)"
        else
          source + quantifier.text
        end
      end

      def convert_subexpressions
        convert_expressions(subexpressions)
      end

      def convert_expressions(expressions)
        expressions.each_with_object(''.dup) do |subexp, source|
          result = Converter.for(subexp).convert(subexp, context)
          source << result[0]
          warnings.concat(result[1])
        end
      end

      def subexpressions
        expression.expressions || []
      end

      def warn_of_unsupported_feature(description = nil)
        description ||= "#{subtype} #{expression.type}".tr('_', ' ')
        full_description = "#{description} '#{expression}'"
        warnings << "Dropped unsupported #{full_description} "\
                    "at index #{expression.ts}"
        ''
      end

      def drop_without_warning
        ''
      end
    end
  end
end
