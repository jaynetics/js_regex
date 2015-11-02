class JsRegex
  #
  module Converter
    require_relative 'group_converter'
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
          open_group(non_capturing: true)
        when :nlookbehind
          context.negative_lookbehind = true
          warn_of_unsupported_feature('negative lookbehind assertion')
        else # :lookbehind, ...
          open_unsupported_group
        end
      end
    end
  end
end
