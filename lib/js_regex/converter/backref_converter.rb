class JsRegex
  #
  module Converter
    require_relative 'base'
    #
    # Template class implementation.
    #
    class BackrefConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :number
          convert_number_backref
        else
          warn_of_unsupported_feature
        end
      end

      def convert_number_backref
        if context.group_count_changed
          warn_of_unsupported_feature('number backreference following a '\
            'feature that changes the group count (such as an atomic group)')
        else
          pass_through
        end
      end
    end
  end
end
