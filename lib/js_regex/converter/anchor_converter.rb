class JsRegex
  #
  module Converter
    require_relative 'base'
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
        when :word_boundary then '\b'
        when :nonword_boundary then '\B'
        else
          warn_of_unsupported_feature
        end
      end
    end
  end
end
