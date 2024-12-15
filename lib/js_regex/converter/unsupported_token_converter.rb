require_relative 'base'

module LangRegex
  module Converter
    #
    # Template class implementation.
    #
    class UnsupportedTokenConverter < Base
      private

      def convert_data
        warn_of_unsupported_feature
      end
    end
  end
end
