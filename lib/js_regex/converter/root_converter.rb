# frozen_string_literal: true

require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class RootConverter < JsRegex::Converter::Base
      private

      def convert_data
        convert_subexpressions
      end
    end
  end
end
