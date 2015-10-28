class JsRegex
  #
  module Converter
    require_relative 'base'
    require_relative 'literal_converter'
    #
    # Template class implementation.
    #
    class EscapeConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :backslash, :codepoint, :form_feed, :return, :hex, :interval_close,
             :interval_open, :newline, :one_or_more, :octal, :space, :set_close,
             :set_open, :dot, :tab, :vertical_tab, :zero_or_more, :zero_or_one
          pass_through
        when :literal
          LiteralConverter.convert(data, self)
        else
          # Backspace, Bell, HexWide, Control, Meta, MetaControl, ...
          warn_of_unsupported_feature
        end
      end
    end
  end
end
