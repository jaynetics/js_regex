# frozen_string_literal: true

require_relative 'base'
require_relative 'group_converter'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    # Note the inheritance from GroupConverter.
    #
    class AssertionConverter < JsRegex::Converter::GroupConverter
      private

      def convert_data
        case subtype
        when :lookahead, :nlookahead
          build_group(capturing: false)
        when :nlookbehind
          warn_of_unsupported_feature('negative lookbehind assertion')
        else # :lookbehind, ...
          build_unsupported_group
        end
      end
    end
  end
end
