class JsRegex
  #
  # This class acts as a facade, passing a Regexp to the Converters.
  #
  # ::of returns a source String, options String, warnings Array, target String.
  #
  class Conversion
    require 'regexp_parser'
    require_relative 'converter'
    require_relative 'error'
    require_relative 'node'
    require_relative 'second_pass'
    require_relative 'target'

    class << self
      def of(input, options: nil, target: Target::ES2009, fail_fast: false)
        target                       = Target.cast(target)
        source, warnings, extra_opts = convert_source(input, target, fail_fast)
        options_string               = convert_options(input, options, extra_opts)
        [source, options_string, warnings, target]
      end

      private

      def convert_source(input, target, fail_fast)
        tree = Regexp::Parser.parse(input)
        context = Converter::Context.new(
          case_insensitive_root: tree.i?,
          target:                target,
          fail_fast:             fail_fast,
        )
        converted_tree = Converter.convert(tree, context)
        final_tree = SecondPass.call(converted_tree)
        [final_tree.to_s, context.warnings, context.required_options]
      rescue Regexp::Parser::Error => e
        raise e.extend(JsRegex::Error)
      end

      def convert_options(input, custom_options, required_options)
        options = custom_options.to_s.scan(/[dgimsuvy]/) + required_options
        if input.is_a?(Regexp) && (input.options & Regexp::IGNORECASE).nonzero?
          options << 'i'
        end
        options.uniq.sort.join
      end
    end
  end
end
