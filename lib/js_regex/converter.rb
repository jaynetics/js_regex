# frozen_string_literal: true

class JsRegex
  module Converter
    Dir[File.join(File.dirname(__FILE__), 'converter', '*.rb')].each do |file|
      require file
    end

    MAP = Hash.new(UnsupportedTokenConverter).merge(
      anchor:      AnchorConverter,
      assertion:   AssertionConverter,
      backref:     BackreferenceConverter,
      conditional: ConditionalConverter,
      escape:      EscapeConverter,
      free_space:  FreespaceConverter,
      group:       GroupConverter,
      literal:     LiteralConverter,
      meta:        MetaConverter,
      nonproperty: NonpropertyConverter,
      property:    PropertyConverter,
      set:         SetConverter,
      type:        TypeConverter
    ).freeze

    def self.for(expression)
      MAP[expression.type].new
    end
  end
end
