class JsRegex
  module Target
    ES2009 = 'ES2009'
    ES2015 = 'ES2015'
    ES2018 = 'ES2018'
    SUPPORTED = [ES2009, ES2015, ES2018].freeze

    def self.cast(arg)
      return ES2009 if arg.nil?

      normalized_arg = arg.to_s.upcase.sub(/^(ECMASCRIPT|ES|JAVASCRIPT|JS)? ?/, 'ES')
      return normalized_arg if SUPPORTED.include?(normalized_arg)

      raise ArgumentError.new(
        "Unknown target: #{arg.inspect}. Try one of #{SUPPORTED}."
      ).extend(JsRegex::Error)
    end
  end
end
