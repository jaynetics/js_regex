class JsRegex
  #
  module Converter
    require_relative 'base'
    #
    # Template class implementation.
    #
    class LiteralConverter < JsRegex::Converter::Base
      def self.convert(data, converter)
        utf8_data = data.dup.force_encoding('UTF-8')
        if /[\u{10000}-\u{FFFFF}]/ =~ utf8_data
          converter.send(:warn_of_unsupported_feature, 'astral plane character')
        else
          escape_literal_forward_slashes(utf8_data)
          ensure_json_compatibility(utf8_data)
          utf8_data
        end
      end

      def self.escape_literal_forward_slashes(data)
        # literal slashes would be mistaken for the pattern end in JsRegex#to_s
        data.gsub!('/', '\\/')
      end

      def self.ensure_json_compatibility(data)
        data.gsub!(/\\?[\f\n\r\t]/) { |lit| Regexp.escape(lit.delete('\\')) }
      end

      private

      def convert_data
        self.class.convert(data, self)
      end
    end
  end
end
