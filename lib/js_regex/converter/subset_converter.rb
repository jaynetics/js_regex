class JsRegex
  #
  module Converter
    require_relative 'set_converter'
    #
    # Simple reroute to SetConverter.
    #
    class SubsetConverter < JsRegex::Converter::SetConverter; end
  end
end
