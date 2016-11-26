# frozen_string_literal: true

class JsRegex
  #
  # This class acts as a facade, creating specific Converters and
  # passing Regexp::Scanner tokens to them, reusing Converters as needed.
  #
  # ::of returns a source String, options String, and warnings Array.
  #
  class Conversion
    require 'regexp_parser'
    Dir[File.join(File.dirname(__FILE__), '**', '*.rb')].each { |f| require f }

    attr_reader :ruby_regex, :context, :converters, :source, :options, :warnings

    def initialize(ruby_regex)
      self.ruby_regex = ruby_regex

      self.context    = Converter::Context.new
      self.converters = {}

      self.source     = ''.dup
      self.options    = ''.dup
      self.warnings   = []

      convert_source
      convert_options
      perform_sanity_check
    end

    def self.of(ruby_regex)
      conversion = new(ruby_regex)
      [conversion.source, conversion.options, conversion.warnings]
    end

    private

    attr_writer :ruby_regex, :context, :converters, :source, :options, :warnings

    CONVERTER_MAP = Hash.new(Converter::UnsupportedTokenConverter).merge(
      anchor:      Converter::AnchorConverter,
      assertion:   Converter::AssertionConverter,
      backref:     Converter::BackreferenceConverter,
      conditional: Converter::ConditionalConverter,
      escape:      Converter::EscapeConverter,
      free_space:  Converter::FreespaceConverter,
      group:       Converter::GroupConverter,
      literal:     Converter::LiteralConverter,
      meta:        Converter::MetaConverter,
      nonproperty: Converter::NonpropertyConverter,
      property:    Converter::PropertyConverter,
      quantifier:  Converter::QuantifierConverter,
      set:         Converter::SetConverter,
      subset:      Converter::SetConverter,
      type:        Converter::TypeConverter
    ).freeze

    def convert_source
      Regexp::Scanner.scan(ruby_regex) do |token_class, subtype, data, s, e|
        # There might be a lot of tokens, so don't wrap their data in objects.
        # Even just wrapping them in simple structs or attr_reader objects
        # can lead to 60%+ longer processing times for large regexes.
        converter_for_token_class(token_class)
          .convert(token_class, subtype, data, s, e)
      end
    end

    def converter_for_token_class(token_class)
      converters[token_class] ||= CONVERTER_MAP[token_class].new(self, context)
    end

    def convert_options
      options << 'g' # all Ruby regexes are what is called "global" in JS
      options << 'i' if (ruby_regex.options & Regexp::IGNORECASE).nonzero?
    end

    SURROGATE_CODEPOINT_PATTERN = /\\uD[89A-F]\h\h/i

    def perform_sanity_check
      # Ruby regex capabilities are a superset of JS regex capabilities in
      # the source part. So if this raises an Error, a Converter messed up.
      # Ignore that Ruby won't accept surrogate pairs, though.
      Regexp.new(source.gsub(SURROGATE_CODEPOINT_PATTERN, '.'))
    rescue ArgumentError, RegexpError, SyntaxError => e
      self.source = ''
      warnings << e.message
    end
  end
end
