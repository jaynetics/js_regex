# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class LiteralConverter < JsRegex::Converter::Base
      def self.convert(data, converter)
        if /[\u{10000}-\u{FFFFF}]/ =~ data
          converter
            .__send__(:warn_of_unsupported_feature, 'astral plane character')
        else
          escape_literal_forward_slashes(data)
          ensure_json_compatibility(data)
          data
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
