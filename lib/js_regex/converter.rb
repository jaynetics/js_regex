module LangRegex
  module Converter
    Dir[File.join(__dir__, 'converter', '*.rb')].sort.each do |file|
      require file
    end

    class Converter
      def initialize(converters_map)
        @converters_map = converters_map
        @converters_map.default ||= UnsupportedTokenConverter
      end

      def convert(exp, context = nil)
        self.for(exp).convert(exp, context || Context.new)
      end

      def for(expression)
        @converters_map[expression.type].new(self)
      end
    end

    class << self
      # Legacy method. Remove in v4.0.0.
      def surrogate_pair_limit=(_arg)
        warn '#surrogate_pair_limit= is deprecated and has no effect anymore.'
      end
    end
  end
end
