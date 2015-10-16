class JsRegex
  module Converter
    #
    # Template class. Implement #convert_data in subclasses.
    #
    class Base
      attr_reader :target, :context

      def initialize(target, context)
        @target = target
        @context = context
      end

      def convert(token_class, subtype, data, start_index, end_index)
        self.token_class = token_class
        self.subtype = subtype
        self.data = data
        self.start_index = start_index
        self.end_index = end_index

        result = convert_data
        target.source << (context.valid? ? result : '')
      end

      private

      attr_accessor :token_class, :subtype, :data, :start_index, :end_index

      def pass_through
        data
      end

      def warn_of_unsupported_feature(description = nil)
        description ||= "#{subtype} #{token_class} '#{data}'".tr('_', ' ')
        target.warnings << "Dropped unsupported #{description} "\
                           "at index #{start_index}..#{end_index}"
        ''
      end
    end
  end
end
