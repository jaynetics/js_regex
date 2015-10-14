class JsRegex
  #
  module Converter
    require_relative 'base'
    #
    # Template class implementation.
    #
    class MetaConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :alternation
          pass_through
        when :dot
          ruby_multiline_mode? ? '(?:.|\n)' : '.'
        else
          warn_of_unsupported_feature
        end
      end

      def ruby_multiline_mode?
        return false if @rb_mm == false
        @rb_mm ||= target.ruby_regex.options & Regexp::MULTILINE > 0
      end
    end
  end
end
