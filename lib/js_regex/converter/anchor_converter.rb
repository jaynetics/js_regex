# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class AnchorConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :bol, :bos then '^'
        when :eol, :eos then '$'
        when :eos_ob_eol then '(?=\n?$)'
        when :word_boundary then pass_boundary_with_warning('\b')
        when :nonword_boundary then pass_boundary_with_warning('\B')
        else
          warn_of_unsupported_feature
        end
      end

      def pass_boundary_with_warning(boundary)
        warn("The boundary '#{boundary}' at index #{expression.ts} "\
             'is not unicode-aware in JavaScript, '\
             'so it might act differently than in Ruby.')
        boundary
      end
    end
  end
end
