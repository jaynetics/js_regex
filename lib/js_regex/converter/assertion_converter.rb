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
          keep_as_is
        when :lookbehind
          return keep_as_is if context.es_2018_or_higher?

          warn_of_unsupported_feature('lookbehind', min_target: Target::ES2018)
          build_passive_group
        when :nlookbehind
          return keep_as_is if context.es_2018_or_higher?

          warn_of_unsupported_feature('negative lookbehind', min_target: Target::ES2018)
        else
          warn_of_unsupported_feature
        end
      end

      def keep_as_is
        build_group(head: pass_through, capturing: false)
      end
    end
  end
end
