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
    end
  end
end
