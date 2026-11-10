# frozen_string_literal: true

# Opt-in migration check:
# bundle exec rspec --require ./spec/support/second_pass_round_trip.rb
require 'js_regex'
require 'js_regex/second_pass/compiler/importer'
require 'js_regex/second_pass/compiler/emitter'

JsRegex::SecondPass.singleton_class.prepend(Module.new do
  def call(tree)
    # Step subclasses inherit this method too. Adapt only the converter's input,
    # not the old pipeline's intermediate trees with unresolved duplicate IDs.
    if self == JsRegex::SecondPass
      compiler = JsRegex::SecondPass::Compiler
      emitted = compiler::Emitter.call(compiler::Importer.call(tree))
      tree.update(type: emitted.type, reference: emitted.reference,
                  quantifier: emitted.quantifier, children: emitted.children)
    end
    super
  end
end)
