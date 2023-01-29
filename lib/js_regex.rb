# JsRegex converts ::Regexp instances to JavaScript.
#
# Usage:
#
# js_regex = JsRegex.new(my_ruby_regex)
# js_regex.to_h  # for use in 'new RegExp()'
# js_regex.to_s  # for direct injection into JavaScript
#
class JsRegex
  require_relative File.join('js_regex', 'conversion')
  require_relative File.join('js_regex', 'error')
  require_relative File.join('js_regex', 'version')
  require 'json'

  attr_reader :source, :options, :warnings, :target

  def initialize(ruby_regex, **kwargs)
    @source, @options, @warnings, @target = Conversion.of(ruby_regex, **kwargs)
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

  # @raise JsRegex::ConversionError
  def self.new!(ruby_regex, **kwargs)
    new(ruby_regex, fail_fast: true, **kwargs)
  end

  def self.compatible?(ruby_regex, **kwargs)
    new!(ruby_regex, **kwargs)
    true
  rescue ConversionError
    false
  end

  ConversionError = Class.new(StandardError).send(:include, JsRegex::Error)
end
