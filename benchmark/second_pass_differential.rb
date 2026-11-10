# frozen_string_literal: true

# Deterministic semantic checks, with separately reported unsupported cases.
# bundle exec ruby -Ilib benchmark/second_pass_differential.rb --seed 1729
require 'json'
require 'optparse'
require 'timeout'
require 'mini_racer'
require_relative '../spec/support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

module SecondPassDifferential
  OracleTimeout = Class.new(StandardError)
  BODIES = ['(a)', '(a*)', '(a*?)', '(a*b*)', '(a*?b*)', '(a|)', '(|a)',
            '(?:(a)|b)', '(?:(a+)|ab)', '(?:(a*)|b)', '(?:b|(a+))',
            '(?:(a)|(b))', '(?:(a+)|(b+))', '(?:(a)|(?(1)b|c))',
            '(?:(?:(a)|b)+|c)', '(a*(b*)?)', '(?:(a*?)|b)',
            '(?:b|(a*))', '(?:(a*)|b|c)', '((?:ab)*)',
            '(?:(a+)|b+)', '(?:(a+)|ba?)', '((a*))',
            '(a*(a*)?)', '(a*(b*)??)', '((?:a|ab)*(b*)?)'].freeze
  QUANTITIES = ['', '?', '??', '*', '*?', '+', '+?', '{1,3}', '{1,3}?', '{2,}', '{2,}?'].freeze
  TAILS = ['\\1', '\\1?', '\\1a', '(?!\\1)a', '(?(1)b|a)', '(?(1)b|a)\\1?'].freeze
  PASSES = { current: JsRegex::SecondPass, compiler: JsRegex::SecondPass::Compiler }.freeze

  def self.patterns(random, count, suite: 'captures')
    return keep_patterns(random, count) if suite == 'keeps'
    return scoped_patterns(random, count) if suite == 'scopes'
    return composite_patterns(random, count) if suite == 'composites'
    return alias_patterns(random, count) if suite == 'aliases'

    candidates = BODIES.product(QUANTITIES, TAILS).map { |parts| parts.join }
    candidates += ['((a)|b)', '((a+)|b)', '(b|(a+))', '((a)?b)']
      .product(QUANTITIES, ['\\2', '\\2\\1', '\\1\\2', '\\2?(?(1)b|a)']).map { |parts| parts.join }
    candidates += ['(?:(a)|(b))+?\\1\\2', '(?:(a+)|(b+))+?\\1\\2']
    candidates.shuffle(random: random).take(count).map do |source|
      Regexp.new(random.rand(2).zero? ? "\\A#{source}\\z" : source)
    end
  end

  def self.scoped_patterns(random, count)
    candidates = ['|a', 'a*?b*?', '|ab|a', 'a??b??']
      .product(['?', '*', '+', '*?', '{2,3}', '{2,3}?'], ['a', 'ab', 'b*', 'a?b', '(?!a)b']).flat_map do |body, quantity, tail|
        inner = '(?:' + body + ')' + quantity + tail
        ['(?=(' + inner + '))\\1b?', '(?!(' + inner + '))a*(?(1)b|a)', '(?>' + inner + ')ab',
         '(?=(?=(' + inner + '))\\1)\\1', '(?!(?=(' + inner + '))\\1)a+']
      end
    candidates += ['a*?', '|a', 'a*?b*?'].product(['*', '+', '*?', '+?'], ['a', 'ab', 'b*', '(?!a)b']).flat_map do |body, quantity, tail|
      inner = '(' + body + ')' + quantity
      ['(?=(' + inner + '\\2' + tail + '))\\1', '(?!(' + inner + '\\2' + tail + '))a+',
       '(?>' + inner + '\\1' + tail + ')ab?', '(?!(?=(' + inner + '\\2' + tail + '))\\1)a+']
    end
    candidates += ['a*', 'a*?', '|a'].product(['?', '??', '|b', 'b|'], ['b', '\\k<n>b', '(?!\\k<n>)a']).flat_map do |body, form, present|
      capture = '(?<n>' + body + ')'
      choice = case form
               when '|b' then '(?:' + capture + '|b)'
               when 'b|' then '(?:b|' + capture + ')'
               else capture + form
               end
      inner = choice + '(?(<n>)' + present + '|a)'
      ['(?=' + inner + ')a*b', '(?!' + inner + ')b+', '(?>' + inner + ')ab?', '(?=(?<out>' + inner + '))\\k<out>']
    end
    candidates += ['(?:(a)|(?(1)b|c))+\\1', '(?:(a)|(b))+?\\1\\2',
                   '(?:(a+)|(b+))+?\\1\\2', '(?:(a+)|ab)+?(?(1)c|a)']
      .product(['(?=%s)a*b*', '(?!%s)a+b*', '(?>%s)ab?', '(?=(?>%s))a+b*']).map do |body, wrapper|
        format(wrapper, body)
      end
    candidates.shuffle(random: random).take(count).map do |source|
      Regexp.new(random.rand(2).zero? ? "\\A#{source}\\z" : source)
    end
  end

  def self.composite_patterns(random, count)
    candidates = ['a*', 'a*?', 'ab*'].product(['b*', 'a*', 'b*?'], ['?', '??'],
                                             ['(?<x>c)', '(?<x>c)?', '(?<x>a*)?', '\\g<x>', '\\g<x>?'],
                                             ['', 'a', '\\k<y>?', '\\k<y>?b']).map do |prefix, inner, quantity, next_capture, tail|
      '(?<x>' + prefix + '(?<y>' + inner + ')' + quantity + ')' + next_capture + '\\k<x>' + tail
    end
    candidates.shuffle(random: random).take(count).map do |source|
      Regexp.new(random.rand(2).zero? ? "\\A#{source}\\z" : source)
    end
  end

  def self.keep_patterns(random, count)
    words = (0..3).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    alternatives = words.flat_map do |word|
      (0..word.length).map do |offset|
        [offset.zero? ? word : word[0...offset] + '\\K' + word[offset..-1], offset]
      end
    end
    pairs = alternatives.product(alternatives).reject { |left, right| left.last == right.last }
    pairs.shuffle(random: random).take(count).map do |pair|
      Regexp.new(pair.map(&:first).join('|'), random.rand(2).zero? ? 0 : Regexp::IGNORECASE)
    end
  end

  def self.alias_patterns(random, count)
    candidates = ['a*', 'a*?', 'a*b*', 'a*?b*?', '|a', 'a|', 'ab|a|', 'a??b??', 'a*?b*', 'a*b*?', 'a?|b']
      .product(['((%s))', '((?:(%s)))', '(((%s)))'], ['*', '+', '*?', '+?', '{2,}', '{3,}?', '{2,4}'],
               ['\\1\\2a', '\\2\\1', '(?!\\2)a', '(?(2)b|a)\\1?', '\\1(b*)\\3', '(?=\\2)\\1b']).map do |body, wrapper, quantity, tail|
        format(wrapper, body) + quantity + tail
      end
    candidates.shuffle(random: random).take(count).map do |source|
      Regexp.new(random.rand(2).zero? ? "\\A#{source}\\z" : source)
    end
  end

  def self.inputs(random, suite: 'captures')
    short = (0..5).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
    longer = Array.new(100) { Array.new(random.rand(6..12)) { %w[a b c].sample(random: random) }.join }
    runs = (1..6).flat_map { |length| ['a' * length, 'a' * length + 'b', 'ab' * length, 'b' * length + 'aab'] }
    strings = (short + longer + runs).uniq
    if suite == 'keeps'
      strings += (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
      strings += strings.map { |string| string.chars.map { |char| random.rand(2).zero? ? char : char.upcase }.join }
    end
    strings.uniq
  end

  def self.evaluate(context, regexp, target, pass, inputs, global: false, oracle_cache: {})
    result = Timeout.timeout(2) { SecondPassCorpus.convert(regexp, target: target, pass: pass) }
    example = SecondPassCorpus.example('generated', regexp, inputs)
    expected = oracle_cache.fetch(regexp) { oracle_cache[regexp] = oracle(example, global: global) }
    raise expected if expected.instance_of?(OracleTimeout)
    [expected, SecondPassCorpus.actual(context, example, result, global: global)]
  end

  # Ruby's regex engine may hold execution too long for Thread-based Timeout.
  # Use its own deadline where available and reuse each oracle result across
  # targets/implementations. Timeouts remain visible instead of dropping inputs.
  def self.oracle(example, global:)
    if Regexp.respond_to?(:timeout)
      example = example.dup
      regexp = example.regexp
      example.regexp = Regexp.new(regexp.source, regexp.options, timeout: 1)
    end
    Timeout.timeout(2, OracleTimeout) { SecondPassCorpus.expected(example, global: global) }
  rescue StandardError => error
    return OracleTimeout.new(error.message) if error.instance_of?(OracleTimeout) ||
      (defined?(Regexp::TimeoutError) && error.instance_of?(Regexp::TimeoutError))
    raise
  end

  # Delete progressively smaller chunks until no deletion preserves the mismatch.
  # Each predicate recompiles through the chosen implementation and Ruby oracle.
  def self.shrink_input(input)
    size = input.length
    while size > 0
      changed = false
      (0..(input.length - size)).each do |index|
        candidate = input[0...index] + input[(index + size)..-1]
        next unless yield candidate
        input = candidate
        changed = true
        break
      end
      size /= 2 unless changed
    end
    input
  end

  # These reductions only remove generated grammar features. Invalid Ruby
  # patterns (for example a removed capture's reference) are never candidates.
  def self.shrink_pattern(regexp)
    loop do
      sources = [regexp.source.sub(/\\A/, ''), regexp.source.sub(/\\z/, '')]
      regexp.source.to_enum(:scan, /\{1,3\}\??|[+*]\??|\?\?/).each do
        match = Regexp.last_match
        sources << regexp.source[0...match.begin(0)] + regexp.source[match.end(0)..-1]
      end
      replacement = sources.uniq.reject { |source| source == regexp.source }.map do |source|
        begin
          Regexp.new(source, regexp.options)
        rescue RegexpError
          nil
        end
      end.compact.find { |candidate| yield candidate }
      return regexp unless replacement
      regexp = replacement
    end
  end

  def self.counterexample(context, regexp, target, pass, input, global: false)
    differs = lambda do |pattern, string|
      expected, actual = evaluate(context, pattern, target, pass, [string], global: global)
      expected != actual
    rescue JsRegex::SecondPass::Compiler::Unsupported, MiniRacer::Error, Timeout::Error, OracleTimeout
      false
    end
    input = shrink_input(input) { |candidate| differs.call(regexp, candidate) }
    regexp = shrink_pattern(regexp) { |candidate| differs.call(candidate, input) }
    input = shrink_input(input) { |candidate| differs.call(regexp, candidate) }
    expected, actual = evaluate(context, regexp, target, pass, [input], global: global)
    { regexp: regexp.source, options: regexp.options, input: input, expected: expected.first, actual: actual.first }
  end

  def self.run(seed: 1729, count: 200, targets: nil, implementation: 'both', suite: 'captures', global: false, max_input_length: nil)
    targets ||= suite == 'keeps' ? [JsRegex::Target::ES2018] : JsRegex::Target::SUPPORTED
    random = Random.new(seed)
    regexps = patterns(random, count, suite: suite)
    strings = inputs(random, suite: suite)
    strings.select! { |input| input.length <= max_input_length } if max_input_length
    passes = PASSES.select { |name, _| implementation == 'both' || name.to_s == implementation }
    context = MiniRacer::Context.new(timeout: 1000)
    oracle_cache = {}
    rows = regexps.flat_map do |regexp|
      targets.flat_map do |target|
        passes.map do |name, pass|
          row = { regexp: regexp.source, options: regexp.options, target: target, implementation: name }
          begin
            expected, actual = evaluate(context, regexp, target, pass, strings, global: global, oracle_cache: oracle_cache)
            index = strings.each_index.find { |i| expected[i] != actual[i] }
            row[:status] = index ? :mismatch : :pass
            row[:counterexample] = counterexample(context, regexp, target, pass, strings[index], global: global) if index
          rescue JsRegex::SecondPass::Compiler::Unsupported => error
            row.merge!(status: :unsupported, reason: error.message)
          rescue MiniRacer::Error => error
            row.merge!(status: :javascript_error, reason: error.message)
          rescue Timeout::Error
            row.merge!(status: :compiler_timeout)
          rescue OracleTimeout
            row.merge!(status: :oracle_timeout)
          end
          row
        end
      end
    end
    { seed: seed, suite: suite, global: global, max_input_length: max_input_length, patterns: regexps.length, inputs: strings.length,
      ruby: RUBY_DESCRIPTION, regexp_parser: Regexp::Parser::VERSION,
      summary: passes.keys.to_h { |name| [name, rows.select { |row| row[:implementation] == name }.group_by { |row| row[:status] }.transform_values(&:length)] },
      results: rows }
  ensure
    context&.dispose
  end
end

if $PROGRAM_NAME == __FILE__
  options = {}
  OptionParser.new do |parser|
    parser.on('--seed N', Integer) { |value| options[:seed] = value }
    parser.on('--patterns N', Integer) { |value| options[:count] = value }
    parser.on('--target TARGET', JsRegex::Target::SUPPORTED) { |value| options[:targets] = [value] }
    parser.on('--implementation NAME', %w[current compiler both]) { |value| options[:implementation] = value }
    parser.on('--suite NAME', %w[captures keeps scopes composites aliases]) { |value| options[:suite] = value }
    parser.on('--global') { options[:global] = true }
    parser.on('--max-input-length N', Integer) { |value| options[:max_input_length] = value }
  end.parse!
  abort 'patterns must be positive' if options.key?(:count) && options[:count] <= 0
  abort 'max-input-length must be nonnegative' if options.key?(:max_input_length) && options[:max_input_length] < 0
  result = SecondPassDifferential.run(**options)
  puts JSON.pretty_generate(result)
  exit 1 if result[:results].any? { |row| [:mismatch, :javascript_error, :compiler_timeout, :oracle_timeout].include?(row[:status]) }
end
