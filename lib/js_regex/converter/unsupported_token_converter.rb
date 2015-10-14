class JsRegex
  #
  module Converter
    require_relative 'base'
    #
    # Template class implementation.
    #
    class UnsupportedTokenConverter < JsRegex::Converter::Base
      private

      def convert_data
        warn_of_unsupported_feature
      end
    end
  end
end
