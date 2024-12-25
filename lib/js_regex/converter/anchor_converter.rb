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
        when :bol then convert_bol
        when :bos then '^'
        when :eol then '(?=$|\n)'
        when :eos then '$'
        when :eos_ob_eol then '(?=\n?$)'
        when :word_boundary then convert_boundary
        when :nonword_boundary then convert_nonboundary
        else
          warn_of_unsupported_feature
        end
      end

      def convert_bol
        if context.es_2018_or_higher?
          '(?<=^|\n(?!$))'
        else
          # TODO: warn in v4.0.0, or drop ES2009 & ES2015 support
          '^'
        end
      end

      def convert_boundary
        if context.es_2018_or_higher? && context.enable_u_option
          BOUNDARY_EXPANSION
        else
          pass_boundary_with_warning
        end
      end

      def convert_nonboundary
        if context.es_2018_or_higher? && context.enable_u_option
          NONBOUNDARY_EXPANSION
        else
          pass_boundary_with_warning
        end
      end

      # This is an approximation to the word boundary behavior in Ruby, c.f.
      # https://github.com/ruby/ruby/blob/08476c45/tool/enc-unicode.rb#L130
      W                     = '\d\p{L}\p{M}\p{Pc}'
      BOUNDARY_EXPANSION    = "(?:(?<=[#{W}])(?=[^#{W}]|$)|(?<=[^#{W}]|^)(?=[#{W}]))"
      NONBOUNDARY_EXPANSION = "(?<=[#{W}])(?=[#{W}])"

      def pass_boundary_with_warning
        warn_of("The anchor '#{data}' at index #{expression.ts} only works "\
                'at ASCII word boundaries with targets below ES2018".')
        pass_through
      end
    end
  end
end
