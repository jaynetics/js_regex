# frozen_string_literal: true

require_relative 'base'
require_relative 'literal_converter'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class EscapeConverter < JsRegex::Converter::Base
      private

      ESCAPES_SHARED_BY_RUBY_AND_JS = %i[
        backslash
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
        octal
        one_or_more
        set_close
        set_open
        tab
        vertical_tab
        zero_or_more
        zero_or_one
      ].freeze

      def convert_data
        case subtype
        when :codepoint_list
          convert_codepoint_list
        when :literal
          LiteralConverter.convert_data(data)
        when *ESCAPES_SHARED_BY_RUBY_AND_JS
          pass_through
        else
          # Bell, Escape, HexWide, Control, Meta, MetaControl, ...
          warn_of_unsupported_feature
        end
      end

      def convert_codepoint_list
        elements = data.scan(/\h+/).map do |codepoint|
          literal = Regexp.escape([codepoint.hex].pack('U'))
          LiteralConverter.convert_data(literal)
        end
        elements.join
      end

      def convert_control_sequence
        convert_meta_control_sequence ||
          unicode_escape_for(control_char_to_s(data[-1]))
      end

      def convert_meta_sequence
        convert_meta_control_sequence ||
          unicode_escape_for(meta_char_to_s(data[-1]))
      end

      def convert_meta_control_sequence
        return false unless expression.class.to_s.include?('MetaControl')
        unicode_escape_for(meta_char_to_s(control_char_to_s(data[-1])))
      end

      def unicode_escape_for(char)
        "\\u#{char.ord.to_s(16).upcase.rjust(4, '0')}"
      end

      def control_char_to_s(control_char)
        five_lsb = control_char.unpack('B*').first[-5..-1]
        ["000#{five_lsb}"].pack('B*')
      end

      def meta_char_to_s(meta_char)
        byte_value = meta_char.ord
        byte_value < 128 ? (byte_value + 128).chr : meta_char
      end
    end
  end
end
