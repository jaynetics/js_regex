class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class LiteralConverter < JsRegex::Converter::Base
      private

      def convert_data
        pass_through
      end
    end
  end
end
