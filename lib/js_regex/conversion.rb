# frozen_string_literal: true

class JsRegex
  #
  # This class acts as a facade, passing a regex to the converters.
  #
  # ::of returns a source String, options String, and warnings Array.
  #
  class Conversion
    require 'regexp_parser'
    require_relative 'converter'

    class << self
      def of(ruby_regex)
        source, warnings = convert_source(ruby_regex)
        options          = convert_options(ruby_regex)
        [source, options, warnings]
      end

      private

      def convert_source(ruby_regex)
        context         = Converter::Context.new(ruby_regex)
        expression_tree = Regexp::Parser.parse(ruby_regex)
        [
          Converter::RootConverter.new.convert(expression_tree, context),
          context.warnings
        ]
      end

      def convert_options(ruby_regex)
        ignore_case = (ruby_regex.options & Regexp::IGNORECASE).nonzero?
        ignore_case ? 'gi' : 'g'
      end
    end
  end
end
