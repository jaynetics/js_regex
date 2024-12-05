require_relative 'base'

module LangRegex
  module Converter
    #
    # Template class implementation.
    #
    class FreespaceConverter < Base
      private

      def convert_data
        drop_without_warning
      end
    end
  end
end
