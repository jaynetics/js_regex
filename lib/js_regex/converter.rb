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
      expression:  SubexpressionConverter,
      free_space:  FreespaceConverter,
      group:       GroupConverter,
      literal:     LiteralConverter,
      meta:        MetaConverter,
      nonproperty: PropertyConverter,
      property:    PropertyConverter,
      set:         SetConverter,
      type:        TypeConverter
    ).freeze

    class << self
      def convert(exp, context = nil)
        self.for(exp).convert(exp, context || Context.new)
      end

      def for(expression)
        MAP[expression.type].new
      end

      # Legacy method. Remove in v4.0.0.
      def surrogate_pair_limit=(_arg)
        warn '#surrogate_pair_limit= is deprecated and has no effect anymore.'
      end
    end
  end
end
