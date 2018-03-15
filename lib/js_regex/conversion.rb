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
      def of(ruby_regex, add_g_flag)
        source, warnings = convert_source(ruby_regex)
        options          = convert_options(ruby_regex, add_g_flag)
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

      def convert_options(ruby_regex, add_g_flag)
        ignore_case = (ruby_regex.options & Regexp::IGNORECASE).nonzero?
        regex_options = ''
        regex_options += 'g' if add_g_flag
        regex_options += 'i' if ignore_case
        regex_options
      end
    end
  end
end
