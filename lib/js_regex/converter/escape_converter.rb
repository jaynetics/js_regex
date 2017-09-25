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

      ESCAPES_SHARED_BY_RUBY_AND_JS = [
        :backslash,
        :bol,
        :carriage,
        :codepoint,
        :dot,
        :eol,
        :form_feed,
        :group_close,
        :group_open,
        :hex,
        :interval_close,
        :interval_open,
        :newline,
        :octal,
        :one_or_more,
        :set_close,
        :set_open,
        :tab,
        :vertical_tab,
        :zero_or_more,
        :zero_or_one
      ].freeze

      def convert_data
        case subtype
        when :codepoint_list
          convert_codepoint_list
        when :control
          convert_control_sequence
        when :literal
          LiteralConverter.convert_data(data)
        when :meta_sequence
          convert_meta_sequence
        when *ESCAPES_SHARED_BY_RUBY_AND_JS
          pass_through
        else
          # Bell, Escape, HexWide, ...
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
          unicode_escape_for(control_sequence_to_s(data))
      end

      def convert_meta_sequence
        convert_meta_control_sequence ||
          unicode_escape_for(meta_char_to_char_code(data[-1]))
      end

      def convert_meta_control_sequence
        return unless expression.class.to_s.include?('MetaControl')
        unicode_escape_for(meta_char_to_char_code(control_sequence_to_s(data)))
      end

      def unicode_escape_for(char)
        "\\u#{char.ord.to_s(16).upcase.rjust(4, '0')}"
      end

      def control_sequence_to_s(control_sequence)
        five_lsb = control_sequence.unpack('B*').first[-5..-1]
        ["000#{five_lsb}"].pack('B*')
      end

      def meta_char_to_char_code(meta_char)
        byte_value = meta_char.ord
        byte_value < 128 ? byte_value + 128 : byte_value
      end
    end
  end
end
