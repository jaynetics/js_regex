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

    # Limit the number of generated surrogate pairs, else the output might
    # get to large for certain applications. The chosen number is somewhat
    # arbitrary. 100 pairs make for about 1 KB, uncompressed. The median char
    # count of all properties supported by Ruby is 92. 75% are below 300 chars.
    #
    # Set this to nil if you need full unicode matches and size doesn't matter.
    class << self
      attr_accessor :surrogate_pair_limit
    end
    self.surrogate_pair_limit = 300
  end
end
