# frozen_string_literal: true

class JsRegex
  module Utils
    module Properties
      class << self
        def name_in_js(name_in_ruby)
          map[name_in_ruby.to_s.delete('_')]
        end

        private

        def map
          @map ||= File.read("#{__dir__}/property_map.csv").scan(/(.+),(.+)/).to_h
        end
      end
    end
  end
end
