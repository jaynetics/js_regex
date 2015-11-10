class JsRegex
  #
  module Converter
    require_relative 'base'
    require_relative 'literal_converter'
    require_relative 'property_converter'
    require_relative 'type_converter'
    #
    # Template class implementation.
    #
    # This converter works a little differently from the others.
    #
    # It buffers anything that it finds within a set in the Context's
    # #buffered_set_members and #buffered_set_extractions Arrays,
    # returning an empty String for all passed tokens, and only when
    # the set is closed does it compile and return the final String.
    #
    class SetConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :open then convert_open_subtype
        when :negate then convert_negate_subtype
        when :close then convert_close_subtype
        when :member, :range, :escape then convert_member_subtype
        when /\Aclass_/ then convert_class_subtype
        when /\Atype_/ then convert_type_subtype
        when :intersection
          warn_of_unsupported_feature("set intersection '&&'")
        else
          # TODO: I think it's a bug in Regexp::Scanner that some property
          # tokens (only positive ones?) are returned with token the class :set
          # within sets. If this's fixed, just warn_of_unsupported_feature here.
          try_replacing_potential_property_subtype
        end
      end

      def convert_open_subtype
        context.open_set
        ''
      end

      def convert_negate_subtype
        if context.set_level > 1
          warn_of_unsupported_feature('nested negative set data')
        end
        context.negate_set
        ''
      end

      def convert_close_subtype
        context.close_set
        context.set_level == 0 ? finalize_set : ''
      end

      def convert_member_subtype
        literal_conversion = LiteralConverter.convert(data, self)
        return '' if literal_conversion == ''
        buffer_set_member(literal_conversion)
      end

      def convert_class_subtype
        negated = subtype.to_s.start_with?('class_non')
        name = subtype.to_s[(negated ? 9 : 6)..-1]
        try_replacing_property(name, negated)
      end

      def try_replacing_potential_property_subtype
        negated = subtype.to_s.start_with?('non')
        name = negated ? subtype.to_s[3..-1] : subtype.to_s
        try_replacing_property(name, negated)
      end

      def try_replacing_property(name, negated)
        replacement = PropertyConverter.property_replacement(name, negated)
        if replacement
          buffer_set_extraction(replacement)
        else
          warn_of_unsupported_feature
        end
      end

      def convert_type_subtype
        if subtype == :type_hex
          buffer_set_extraction(TypeConverter::HEX_EXPANSION)
        elsif subtype == :type_nonhex
          buffer_set_extraction(TypeConverter::NONHEX_EXPANSION)
        else
          buffer_set_member(data)
        end
      end

      def buffer_set_member(string)
        buffered_members << string unless context.nested_negation?
        ''
      end

      def buffer_set_extraction(string)
        buffered_extractions << string unless context.nested_negation?
        ''
      end

      def buffered_members
        context.buffered_set_members
      end

      def buffered_extractions
        context.buffered_set_extractions
      end

      def finalize_set
        if buffered_members.none?
          finalize_depleted_set
        else
          set = build_set(buffered_members, context.negative_set?(1))
          if buffered_extractions.any?
            "(?:#{set}|#{buffered_extractions.join('|')})"
          else
            set
          end
        end
      end

      def finalize_depleted_set
        case buffered_extractions.count
        when 0 then ''
        when 1 then buffered_extractions.first
        else "(?:#{buffered_extractions.join('|')})"
        end
      end

      def build_set(members, negative)
        "[#{negative ? '^' : ''}#{members.join}]"
      end
    end
  end
end
