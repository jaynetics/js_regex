# frozen_string_literal: true

# bundle exec ruby -Ilib benchmark/second_pass.rb --iterations 10 > /tmp/second-pass.json
require 'json'
require 'optparse'
require 'mini_racer'
require_relative '../spec/support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

module SecondPassBenchmark
  def self.clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.measure(iterations)
    allocated = GC.stat(:total_allocated_objects)
    started = clock
    iterations.times { |index| yield index }
    elapsed = clock - started
    allocations = GC.stat(:total_allocated_objects) - allocated
    { milliseconds: elapsed * 1000 / iterations, allocations: allocations.to_f / iterations }
  end

  def self.capture_count(tree)
    return 0 if tree.instance_of?(String)

    (tree.type == :captured_group ? 1 : 0) + tree.children.sum { |child| capture_count(child) }
  end

  def self.growth_cases
    bounded = [2, 4, 8, 16].map do |bound|
      SecondPassCorpus.example("bounded growth #{bound}", Regexp.new("\\A(?:(a)|b){#{bound}}\\1\\z"),
                               ['a' * (bound + 1), 'b' * (bound + 1)])
    end
    conditional = [1, 2, 3, 4].map do |count|
      source = '\\A' + '(a*)?' * count + (1..count).map { |id| "(?(#{id})b|c)" }.join + '\\z'
      SecondPassCorpus.example("conditional growth #{count}", Regexp.new(source),
                               ['b' * count, 'c' * count, 'a' * count])
    end
    bounded + conditional
  end

  def self.stress_cases
    patterns = { 'nullable failure' => /\A(a*)*\1\z/,
                 'overlapping retention failure' => /\A(?:(ab+)|a)+\1\z/,
                 'lazy empty-first failure' => /\A(a*?)*?\1a\z/,
                 'lazy empty-sequence failure' => /\A(a*?b*?)*?\1a\z/,
                 'lazy consuming-first failure' => /\A(a*b*)*?\1a\z/,
                 'lazy run failure' => /\A(?:(a+)|(b+))+?\1\2\z/,
                 'required nullable prefix failure' => /\A((a*b*)){3,}?\1\2a\z/,
                 'guarded capture failure' => /\A((a*b*)*?\2)b\z/,
                 'unobserved nested capture failure' => /\A(a*(b*)?)*\1a\z/,
                 'mixed empty-path failure' => /\A(a*?b*)*?\1a\z/ }
    patterns.flat_map do |name, regexp|
      [16, 64, 256].map do |length|
        SecondPassCorpus.example("#{name} #{length}", regexp, ['a' * length + 'b' * length + 'c'])
      end
    end
  end

  def self.javascript_times(context, result, inputs, iterations)
    context.eval("var source = #{result.source.to_json}, flags = #{result.options.to_json};")
    # These are host-observed timings, including one JS boundary crossing per
    # batch. Engines may cache compilation; report this as construction time.
    construction = measure(1) do
      # Do not marshal the loop's final RegExp back into a Ruby Regexp. The two
      # engines have different syntax, particularly for Unicode escapes.
      context.eval("for (var i = 0; i < #{iterations}; i++) new RegExp(source, flags); null;")
    end[:milliseconds] / iterations
    context.eval("var regexp = new RegExp(source, flags), inputs = #{inputs.to_json};")
    matching = measure(1) do
      context.eval(<<~JS)
        var hits = 0;
        for (var i = 0; i < #{iterations}; i++) {
          for (var j = 0; j < inputs.length; j++) hits += regexp.test(inputs[j]) ? 1 : 0;
        }
        hits;
      JS
    end[:milliseconds] / (iterations * inputs.length)
    { construction_ms: construction, match_ms_per_input: matching }
  rescue MiniRacer::ScriptTerminatedError
    { timeout: true }
  end

  def self.run(iterations: 10, samples: 3, pass: JsRegex::SecondPass, targets: JsRegex::Target::SUPPORTED, stress: false)
    context = MiniRacer::Context.new(timeout: 1000)
    examples = SecondPassCorpus::CASES + growth_cases + (stress ? stress_cases : [])
    rows = examples.flat_map do |example|
      (example.targets & targets).map do |target|
        template, = SecondPassCorpus.prepare(example.regexp, target)
        2.times { pass.call(template.clone) }
        result = SecondPassCorpus.convert(example.regexp, target: target, pass: pass)
        tree = pass.call(template.clone)
        measurements = Array.new(samples) do
          # Input copying is setup, not SecondPass execution. Each run mutates
          # its own tree, just as it would in an actual conversion.
          inputs = Array.new(iterations) { template.clone }
          {
            second_pass: measure(iterations) { |index| pass.call(inputs[index]) },
            conversion: measure(iterations) { SecondPassCorpus.convert(example.regexp, target: target, pass: pass) },
            javascript: javascript_times(context, result, example.inputs, iterations * 20),
          }
        end
        { name: example.name, regexp: example.regexp.source, target: target,
          source_bytes: result.source.bytesize, captures: capture_count(tree), samples: measurements }
      rescue JsRegex::SecondPass::Compiler::Unsupported => error
        { name: example.name, regexp: example.regexp.source, target: target, unsupported: error.message }
      end
    end
    { ruby: RUBY_DESCRIPTION, regexp_parser: Regexp::Parser::VERSION, mini_racer: MiniRacer::VERSION,
      implementation: pass.name, iterations: iterations, samples: samples, results: rows }
  ensure
    context&.dispose
  end
end

if $PROGRAM_NAME == __FILE__
  options = {}
  OptionParser.new do |parser|
    parser.on('--iterations N', Integer) { |value| options[:iterations] = value }
    parser.on('--samples N', Integer) { |value| options[:samples] = value }
    parser.on('--target TARGET', JsRegex::Target::SUPPORTED) { |value| options[:targets] = [value] }
    parser.on('--stress') { options[:stress] = true }
    parser.on('--implementation NAME', %w[current compiler]) do |value|
      options[:pass] = value == 'compiler' ? JsRegex::SecondPass::Compiler : JsRegex::SecondPass
    end
  end.parse!
  [:iterations, :samples].each do |key|
    abort "#{key} must be positive" if options.key?(key) && options[key] <= 0
  end
  puts JSON.pretty_generate(SecondPassBenchmark.run(**options))
end
