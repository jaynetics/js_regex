# frozen_string_literal: true

require_relative 'base'
require 'character_set'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class PropertyConverter < JsRegex::Converter::Base
      private

      def convert_data
        convert_property
      end

      def convert_property(negated = nil)
        content = CharacterSet.of_property(subtype)
        if expression.case_insensitive? && !context.case_insensitive_root
          content = content.case_insensitive
        end

        if negated
          if content.astral_part.empty?
            return "[^#{content.to_s(format: :js)}]"
          else
            warn_of_unsupported_feature('astral plane negation by property')
          end
        elsif Converter.surrogate_pair_limit.nil? ||
              Converter.surrogate_pair_limit >= content.astral_part.size
          return content.to_s_with_surrogate_alternation
        else
          warn_of_unsupported_feature('large astral plane match of property')
        end

        bmp_part = content.bmp_part
        return '' if bmp_part.empty?

        string = bmp_part.to_s(format: :js)
        negated ? "[^#{string}]" : "[#{string}]"
      end
    end
  end
end
