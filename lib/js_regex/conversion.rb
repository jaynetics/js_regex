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
    require_relative 'node'
    require_relative 'second_pass'

    class << self
      def of(ruby_regex, options: nil)
        source, warnings = convert_source(ruby_regex)
        options_string   = convert_options(ruby_regex, options)
        [source, options_string, warnings]
      end

      private

      def convert_source(ruby_regex)
        tree = Regexp::Parser.parse(ruby_regex)
        context = Converter::Context.new(case_insensitive_root: tree.i?)
        converted_tree = Converter.convert(tree, context)
        final_tree = SecondPass.call(converted_tree)
        [final_tree.to_s, context.warnings]
      end

      def convert_options(ruby_regex, custom_options)
        options = custom_options.to_s.scan(/[gimuy]/)
        options << 'i' if (ruby_regex.options & Regexp::IGNORECASE).nonzero?
        options.uniq.sort.join
      end
    end
  end
end
