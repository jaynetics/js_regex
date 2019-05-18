# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class MetaConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :alternation
          convert_alternatives
        when :dot
          expression.multiline? ? '(?:.|\n)' : '.'
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
