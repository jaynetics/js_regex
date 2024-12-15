module LangRegex
  module Target
    ES2009 = 'ES2009'
    ES2015 = 'ES2015'
    ES2018 = 'ES2018'

    PCRE   = 'PCRE'

    FULLY_SUPPORTED = [ES2009, ES2015, ES2018].freeze
    PARTIALLY_SUPPORTED = [PCRE].freeze
    SUPPORTED = [*FULLY_SUPPORTED, *PARTIALLY_SUPPORTED].freeze

    def self.cast(arg)
      return ES2009 if arg.nil?
      return arg if SUPPORTED.include?(arg)

      normalized_arg = arg.to_s.upcase.sub(/^(ECMASCRIPT|ES|JAVASCRIPT|JS)? ?/, 'ES')
      return normalized_arg if SUPPORTED.include?(normalized_arg)

      raise ArgumentError.new(
        "Unknown target: #{arg.inspect}. Try one of #{SUPPORTED}."
      ).extend(::LangRegex::Error)
    end
  end
end
