class JsRegex
  #
  module Converter
    require_relative 'base'
    #
    # Template class implementation.
    #
    class FreespaceConverter < JsRegex::Converter::Base
      private

      def convert_data
        '' # drop data without warning
      end
    end
  end
end
