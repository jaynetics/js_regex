require_relative 'base'
require_relative 'literal_converter'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class EscapeConverter < JsRegex::Converter::Base
      ESCAPES_SHARED_BY_RUBY_AND_JS = %i[
        alternation
        backslash
        backspace
        bol
        carriage
        codepoint
        dot
        eol
        form_feed
        group_close
        group_open
        hex
        interval_close
        interval_open
        newline
        one_or_more
        set_close
        set_open
        tab
        vertical_tab
        zero_or_more
        zero_or_one
      ].freeze

      private

      def convert_data
        case subtype
        when :codepoint_list
          convert_codepoint_list
        when :control, :meta_sequence
          unicode_escape_codepoint
        when :literal
          LiteralConverter.convert_data(expression.char, context)
        when :bell, :escape, :hex, :octal
          hex_escape_codepoint
        when *ESCAPES_SHARED_BY_RUBY_AND_JS
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
            node << LiteralConverter.convert_data(Regexp.escape(char), context)
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
