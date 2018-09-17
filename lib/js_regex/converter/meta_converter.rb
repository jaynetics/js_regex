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
        kept_any = false

        convert_subexpressions.map do |node|
          dropped = !node.children.empty? && node.children.all?(&:dropped?)
          node.children.unshift('|') if kept_any.equal?(true) && !dropped
          kept_any = true unless dropped
          node
        end
      end
    end
  end
end
