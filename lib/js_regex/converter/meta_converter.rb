require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class MetaConverter < JsRegex::Converter::Base
      DOT_EXPANSION    = '(?:[\uD800-\uDBFF][\uDC00-\uDFFF]|[^\n\uD800-\uDFFF])'
      ML_DOT_EXPANSION = '(?:[\uD800-\uDBFF][\uDC00-\uDFFF]|[^\uD800-\uDFFF])'
      # Possible improvements for dot conversion:
      #
      # In ES2015, the 'u' flag allows dots to match astral chars. Unfortunately
      # the dot keeps matching lone surrogates even with this flag, so the use
      # of an expansion is still necessary to get the same behavior as in Ruby.
      #
      # ES2018 has the dotall flag 's', but it is tricky to use in conversions.
      # 's' activates matching of BOTH astral chars and "\n", whereas the dot in
      # Ruby doesn't match "\n" by default, and even with the 'm' flag set on
      # the root, subexps might still exclude "\n" like so: /.(?-m:.)./m

      private

      def convert_data
        case subtype
        when :alternation
          convert_alternatives
        when :dot
          expression.multiline? ? ML_DOT_EXPANSION : DOT_EXPANSION
        else
          warn_of_unsupported_feature
        end
      end

      def convert_alternatives
        kept_any_previous_branch = nil

        convert_subexpressions.transform do |node|
          unless dropped_branch?(node)
            node.children.unshift('|') if kept_any_previous_branch
            kept_any_previous_branch = true
          end
          node
        end
      end

      def dropped_branch?(branch_node)
        branch_node.children.any? && branch_node.children.all?(&:dropped?)
      end
    end
  end
end
