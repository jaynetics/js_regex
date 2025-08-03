# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class EscapeConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :codepoint_list
          convert_codepoint_list
        when :control, :meta_sequence, :utf8_hex
          unicode_escape_codepoint
        when :literal
          Utils::Literals.convert_data(expression.char, context)
        when :bell, :escape, :hex, :octal
          hex_escape_codepoint
        when *Utils::Escapes::ESCAPES_SHARED_BY_RUBY_AND_JS
          pass_through
        else
          warn_of_unsupported_feature
        end
      end

      def convert_codepoint_list
        if context.enable_u_option
          split_codepoint_list
        else
          expression.chars.each_with_object(Node.new) do |char, node|
            node << Utils::Literals.convert_data(Regexp.escape(char), context)
          end
        end
      end

      def split_codepoint_list
        expression.codepoints.map { |cp| "\\u{#{cp.to_s(16).upcase}}" }.join
      end

      def unicode_escape_codepoint
        "\\u#{expression.codepoint.to_s(16).upcase.rjust(4, '0')}"
      end

      def hex_escape_codepoint
        "\\x#{expression.codepoint.to_s(16).upcase.rjust(2, '0')}"
      end
    end
  end
end
