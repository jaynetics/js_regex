require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class KeepConverter < JsRegex::Converter::Base
      private

      def convert_data
        if context.es_2018_or_higher?
          if expression.level.zero?
            Node.new(type: :keep_mark) # mark for conversion in SecondPass
          else
            warn_of_unsupported_feature('nested keep mark')
          end
        else
          warn_of_unsupported_feature('keep mark', min_target: Target::ES2018)
        end
      end
    end
  end
end
