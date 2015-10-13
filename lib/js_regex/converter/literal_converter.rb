class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class LiteralConverter < JsRegex::Converter::Base
      private

      def convert_data
        if data == "\n"
          '\\n'
        else
          pass_through
        end
      end
    end
  end
end
