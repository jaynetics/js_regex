# frozen_string_literal: true

# Opt-in integration audit. Explicitly selected legacy steps retain their own
# unit tests; ordinary conversions use the compiler. Production never loads this.
# bundle exec rspec --require ./spec/support/second_pass_compiler.rb
require 'js_regex'
require 'js_regex/second_pass/compiler/pipeline'

original_steps = JsRegex::SecondPass::STEPS
JsRegex::SecondPass.singleton_class.prepend(Module.new do
  define_method(:call) do |tree|
    if self == JsRegex::SecondPass && JsRegex::SecondPass::STEPS.equal?(original_steps)
      JsRegex::SecondPass::Compiler.call(tree)
    else
      super(tree)
    end
  end
end)
