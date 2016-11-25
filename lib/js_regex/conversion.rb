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
      @ruby_regex = ruby_regex

      @context    = Converter::Context.new
      @converters = {}

      @source     = +''
      @options    = +''
      @warnings   = []

      convert_source(ruby_regex)
      convert_options(ruby_regex)
      perform_sanity_check
    end

    def self.of(ruby_regex)
      conversion = new(ruby_regex)
      [conversion.source, conversion.options, conversion.warnings]
    end

    private

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

    def convert_source(ruby_regex)
      Regexp::Scanner.scan(ruby_regex) do |token_class, subtype, data, s, e|
        # There might be a lot of tokens, so don't wrap their data in objects.
        # Even just wrapping them in simple structs or attr_reader objects
        # can lead to 60%+ longer processing times for large regexes.
        convert_token(token_class, subtype, data, s, e)
      end
      converters.clear
    end

    def convert_token(token_class, subtype, data, s, e)
      converter = converter_for_token_class(token_class)
      converter.convert(token_class, subtype, data, s, e)
    end

    def converter_for_token_class(token_class)
      converters[token_class] ||= CONVERTER_MAP[token_class].new(self, context)
    end

    def convert_options(ruby_regex)
      @options = 'g' # all Ruby regexes are what is called "global" in JS
      @options << 'i' if ruby_regex.options & Regexp::IGNORECASE > 0
    end

    def perform_sanity_check
      # Ruby regex capabilities are a superset of JS regex capabilities in
      # the source part. So if this raises an Error, a Converter messed up:
      Regexp.new(source, options)
    rescue ArgumentError, RegexpError, SyntaxError => e
      @source = ''
      warnings << e.message
    end
  end
end
