# frozen_string_literal: true

require_relative 'base'
require_relative 'literal_converter'
require_relative 'property_converter'
require_relative 'type_converter'

class JsRegex
  module Converter
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
        when :member, :member_hex, :range, :range_hex, :escape
          convert_member_subtype
        when /\Aclass_/ then convert_class_subtype
        when /\Atype_/ then convert_type_subtype
        when :backspace then convert_backspace_subtype
        when :intersection then warn_of_unsupported_feature('set intersection')
        else try_replacing_potential_property_subtype
        end
      end

      def convert_open_subtype
        context.open_set
        ''
      end

      def convert_negate_subtype
        if context.nested_set?
          warn_of_unsupported_feature('nested negative set data')
        end
        context.negate_set
        ''
      end

      def convert_close_subtype
        context.close_set
        context.set? ? '' : finalize_set
      end

      def convert_member_subtype
        utf8_data = data.force_encoding('UTF-8')
        if /[\u{10000}-\u{FFFFF}]/ =~ utf8_data
          warn_of_unsupported_feature('astral plane set member')
        else
          literal_conversion = LiteralConverter.convert_data(utf8_data)
          buffer_set_member(literal_conversion)
        end
      end

      def convert_class_subtype
        negated = subtype.to_s.start_with?('class_non')
        name = subtype[(negated ? 9 : 6)..-1]
        try_replacing_property(name, negated)
      end

      def try_replacing_potential_property_subtype
        negated = data.start_with?('\\P')
        try_replacing_property(subtype, negated)
      end

      def try_replacing_property(name, negated)
        if (replacement = PropertyConverter.property_replacement(name, negated))
          buffer_set_extraction(replacement)
        else
          warn_of_unsupported_feature('property')
        end
      end

      def convert_type_subtype
        if subtype.equal?(:type_hex)
          buffer_set_extraction(TypeConverter::HEX_EXPANSION)
        elsif subtype.equal?(:type_nonhex)
          buffer_set_extraction(TypeConverter::NONHEX_EXPANSION)
        else
          buffer_set_member(data)
        end
      end

      def convert_backspace_subtype
        buffer_set_extraction('[\b]')
      end

      def buffer_set_member(m)
        context.buffered_set_members << m unless context.nested_negation?
        ''
      end

      def buffer_set_extraction(e)
        context.buffered_set_extractions << e unless context.nested_negation?
        ''
      end

      def finalize_set
        buffered_members     = context.buffered_set_members
        buffered_extractions = context.buffered_set_extractions
        if buffered_members.empty?
          finalize_depleted_set(buffered_extractions)
        else
          finalize_nondepleted_set(buffered_members, buffered_extractions)
        end
      end

      def finalize_depleted_set(buffered_extractions)
        case buffered_extractions.count
        when 0 then ''
        when 1 then buffered_extractions.first
        else "(?:#{buffered_extractions.join('|')})"
        end
      end

      def finalize_nondepleted_set(buffered_members, buffered_extractions)
        set = "[#{'^' if context.negative_set?(1)}#{buffered_members.join}]"
        if buffered_extractions.empty?
          set
        else
          "(?:#{set}|#{buffered_extractions.join('|')})"
        end
      end
    end
  end
end
