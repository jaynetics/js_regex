# frozen_string_literal: true

class JsRegex
  module Utils
    module CharTypes
      def self.directly_compatible?(expression)
        case expression.token
        when :space, :nonspace
          !expression.ascii_classes?
        when :digit, :nondigit, :word, :nonword
          !expression.unicode_classes?
        else # :hex, :nonhex, :linebreak, :xgrapheme
          false
        end
      end
    end
  end
end
