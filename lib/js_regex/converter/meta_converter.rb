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
          pass_through
        when :dot
          ruby_multiline_mode? ? '(?:.|\n)' : '.'
        else
          warn_of_unsupported_feature
        end
      end

      def ruby_multiline_mode?
        (target.ruby_regex.options & Regexp::MULTILINE).nonzero?
      end
    end
  end
end
