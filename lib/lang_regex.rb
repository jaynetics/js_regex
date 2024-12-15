module LangRegex
  class LangRegex
    require_relative File.join('js_regex', 'conversion')
    require_relative File.join('js_regex', 'error')
    require_relative File.join('js_regex', 'version')

    require_relative File.join('js_regex', 'langs', 'js', 'js_regex')
    require_relative File.join('js_regex', 'langs', 'php', 'php_regex')

    require 'json'

    attr_reader :source, :options, :warnings, :target

    def initialize(ruby_regex, converter, **kwargs)
      @source, @options, @warnings, @target = Conversion.of(ruby_regex, converter, **kwargs)
    end

    def to_h
      { source: source, options: options }
    end

    def to_json(options = {})
      to_h.to_json(options)
    end

    def to_s
      "/#{source.empty? ? '(?:)' : source}/#{options}"
    end

    # @raise LangRegex::ConversionError
    def self.new!(ruby_regex, **kwargs)
      new(ruby_regex, fail_fast: true, **kwargs)
    end

    def self.compatible?(ruby_regex, **kwargs)
      new!(ruby_regex, **kwargs)
      true
    rescue ConversionError
      false
    end
  end
  ConversionError = ::Class.new(StandardError).send(:include, Error)
end
