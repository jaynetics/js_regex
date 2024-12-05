module LangRegex
  # JsRegex converts ::Regexp instances to JavaScript.
  #
  # Usage:
  #
  # js_regex = LangRegex::JsRegex.new(my_ruby_regex)
  # js_regex.to_h  # for use in 'new RegExp()'
  # js_regex.to_s  # for direct injection into JavaScript
  #
  class JsRegex < LangRegex
    def initialize(ruby_regex, **kwargs)
      super(ruby_regex, self.class.js_converter, **kwargs)
    end

    def self.js_converter
      Converter::Converter.new(
        {
          anchor:      Converter::AnchorConverter,
          assertion:   Converter::AssertionConverter,
          backref:     Converter::BackreferenceConverter,
          conditional: Converter::ConditionalConverter,
          escape:      Converter::EscapeConverter,
          expression:  Converter::SubexpressionConverter,
          free_space:  Converter::FreespaceConverter,
          group:       Converter::GroupConverter,
          keep:        Converter::KeepConverter,
          literal:     Converter::LiteralConverter,
          meta:        Converter::MetaConverter,
          nonproperty: Converter::PropertyConverter,
          property:    Converter::PropertyConverter,
          set:         Converter::SetConverter,
          type:        Converter::TypeConverter
        }
      )
    end
  end
end
