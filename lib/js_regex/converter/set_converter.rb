# frozen_string_literal: true

require_relative 'base'
require_relative 'literal_converter'
require_relative 'property_converter'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class SetConverter < JsRegex::Converter::Base
      private

      def convert_data
        if expression.set_level.equal?(0) # reached end of set expression
          context.reset_set_context
          context.negate_base_set if negative_set?
          process_members
          finalize_set
        elsif negative_set?
          warn_of_unsupported_feature('nested negative set data')
        else # positive subset
          process_members
        end
      end

      def negative_set?
        expression.negative?
      end

      def process_members
        expression.each { |member| process_member(member) }
      end

      ASTRAL_PLANE_PATTERN = /[\u{10000}-\u{FFFFF}]/
      PROPERTY_PATTERN     = /\A(?:\[:|\\([pP])\{)(\^?)([^:\}]+)/

      def process_member(member)
        return convert_subset(member) unless member.instance_of?(String)

        utf8_data = member.dup.force_encoding('UTF-8')
        case utf8_data
        when ASTRAL_PLANE_PATTERN
          warn_of_unsupported_feature('astral plane set member')
        when '\\h'
          handle_hex_type
        when '\\H'
          handle_nonhex_type
        when '&&'
          warn_of_unsupported_feature('set intersection')
        when PROPERTY_PATTERN
          handle_property($1, $2, $3)
        else
          handle_literal(utf8_data)
        end
      end

      HEX_RANGES = 'A-Fa-f0-9'
      NONHEX_SET = '[^A-Fa-f0-9]'

      def handle_hex_type
        buffer_set_member(HEX_RANGES)
      end

      def handle_nonhex_type
        if context.negative_base_set
          warn_of_unsupported_feature('nonhex type in negative set')
        else
          buffer_set_extraction(NONHEX_SET)
        end
      end

      def handle_property(sign, caret, name)
        if context.negative_base_set
          return warn_of_unsupported_feature('property in negative set')
        end
        std = standardize_property_name(name)
        negated = sign.eql?('P') ^ caret.eql?('^')
        if (replacement = PropertyConverter.property_replacement(std, negated))
          buffer_set_extraction(replacement)
        else
          warn_of_unsupported_feature('property')
        end
      end

      def handle_literal(utf8_data)
        conversion = LiteralConverter.convert_data(utf8_data)
        if context.case_insensitive_root && !expression.case_insensitive?
          warn_of_unsupported_feature('nested case-sensitive set member')
        elsif !context.case_insensitive_root && expression.case_insensitive?
          return handle_locally_case_insensitive_literal(conversion)
        end
        buffer_set_member(conversion)
      end

      DESCENDING_CASE_RANGE_PATTERN = /\p{upper}-\p{lower}/

      def handle_locally_case_insensitive_literal(literal)
        buffer_set_member(
          if literal =~ DESCENDING_CASE_RANGE_PATTERN
            warn_of_unsupported_feature(
              'nested case-insensitive range going from upper to lower case'
            )
            literal
          else
            [literal, literal.swapcase].uniq
          end
        )
      end

      def standardize_property_name(name)
        Regexp::Parser.parse("\\p{#{name}}").expressions.first.token
      end

      def buffer_set_member(data)
        context.buffered_set_members << data
      end

      def buffer_set_extraction(data)
        context.buffered_set_extractions << data
      end

      def convert_subset(subset)
        SetConverter.new.convert(subset, context)
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
        set = "[#{'^' if negative_set?}#{buffered_members.join}]"
        if buffered_extractions.empty?
          set
        else
          "(?:#{set}|#{buffered_extractions.join('|')})"
        end
      end
    end
  end
end
