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

      # Limit the number of generated surrogate pairs, else the output might
      # get to large for certain applications. The chosen number is somewhat
      # arbitrary. 100 pairs make for about 1 KB, uncompressed. The median char
      # count of all properties supported by Ruby is 92. 75% are below 300 chars.
      #
      # Set this to nil if you need full unicode matches and size doesn't matter.
      attr_accessor :surrogate_pair_limit
    end
    self.surrogate_pair_limit = 300
  end
end
