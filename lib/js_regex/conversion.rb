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
      def of(input, options: nil)
        source, warnings = convert_source(input)
        options_string   = convert_options(input, options)
        [source, options_string, warnings]
      end

      private

      def convert_source(input)
        tree = Regexp::Parser.parse(input)
        context = Converter::Context.new(case_insensitive_root: tree.i?)
        converted_tree = Converter.convert(tree, context)
        final_tree = SecondPass.call(converted_tree)
        [final_tree.to_s, context.warnings]
      end

      def convert_options(input, custom_options)
        options = custom_options.to_s.scan(/[gimuy]/)
        if input.is_a?(Regexp) && (input.options & Regexp::IGNORECASE).nonzero?
          options << 'i'
        end
        options.uniq.sort.join
      end
    end
  end
end
