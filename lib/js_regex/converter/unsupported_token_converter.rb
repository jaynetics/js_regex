# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
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
