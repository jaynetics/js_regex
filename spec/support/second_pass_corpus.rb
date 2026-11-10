# frozen_string_literal: true

require 'js_regex'

# Shared by the rewrite's differential specs and standalone benchmarks. Keep
# expected behavior in Ruby, rather than snapshots of the old generated source.
module SecondPassCorpus
  Case = Struct.new(:name, :regexp, :inputs, :targets, :groups, keyword_init: true)
  Result = Struct.new(:source, :options, :warnings, keyword_init: true)

  def self.example(name, regexp, inputs, groups: false, targets: JsRegex::Target::SUPPORTED)
    Case.new(name: name, regexp: regexp, inputs: inputs, targets: targets, groups: groups)
  end

  SHORT_INPUTS = (0..4).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }.freeze

  CASES = [
    example('plain', /a+b?/, SHORT_INPUTS, groups: true),
    example('required reference', /(a)\1/, SHORT_INPUTS, groups: true),
    example('forward reference', /\1(a)/, SHORT_INPUTS),
    example('optional capture', /(a)?\1/, SHORT_INPUTS),
    example('nullable capture', /\A(a*)?\1\z/, SHORT_INPUTS),
    example('nullable conditional', /\A(a*)?(?(1)b|a)\z/, ['', 'a', 'b', 'ab', 'aab', 'aa']),
    example('conditional priority', /(a)??(?(1)b|a)/, ['ab', 'a', 'b', 'aab']),
    example('bounded retention', /\A(?:(ab+)|a){1,3}\1\z/, %w[abaab abbaabb aba]),
    example('bounded empty iterations', /\A(a*?){1,3}(?(1)b|a)\1?/, %w[aba aaba]),
    example('constant loop state', /\A(?:(a)|(?(1)b|c))+\1\z/, %w[aa aba caba ca ba aca]),
    example('retained variable value', /\A(?:(ab+)|a)+\1\z/, %w[abaab abbaabb aba ababb]),
    example('nested retention', /\A(?:(?:(a)|b)+|c)+\1\z/, %w[aa aba aca abca b bc c]),
    example('final empty iteration', /\A(a*)*\1\z/, ['', 'a', 'aa', 'aaa']),
    example('empty iteration backtracking', /\A(a*)*(?!\1)a\z/, %w[a aaa aa]),
    example('overlapping lazy branches', /(?:(a+)|ab)+?(?(1)c|a)/, %w[aabc aaba]),
    example('multiple lazy captures', /(?:(a+)|(b+))+?\1\2/,
            %w[abab abaab abbabab baaabab baabaab baabab abaabab baababa aabbaaabbb]),
    example('duplicate name commitment', /(?<n>x)(?<n>xx)\k<n>x/, %w[xxxxx xxxxxx], groups: true),
    example('duplicate name fallback', /(?<n>a)(?<n>b)\k<n>/, %w[aba abb ab], groups: true),
    example('subexpression participation', /\A(a)?\g<1>(?(1)b|c)\z/, %w[ab aab ac aac]),
    example('discarded conditional captures', /\A(a*)?(?(1)b|(c(d)))(?(3)e|f)\z/,
            %w[bf aabf cde be cdf aabe]),
    example('atomic capture', /\A(?>a|ab)c\z/, %w[ac abc aac]),
    example('negative assertion scope', /\A(?!(a))b\1\z/, ['', 'b', 'ba', 'a']),
    example('numeric reference delimiter', /\A(a)(?(1)b)\k<1>0\z/, ['aba0', 'ab0', "ab\b"]),
    example('astral retention', /\A(?:(😋)|b)+\1\z/, %w[😋b😋 b 😋b]),
    example('astral match offset', /(a)\1/, ['😋aa', '😋ba', '😋😋aa'], groups: true),
    example('keep mark', /a\Kb/, %w[ab aab b], targets: [JsRegex::Target::ES2018]),
  ].freeze

  # Use a fresh converter tree for each implementation. No production constants
  # are stubbed, and no conversion cache can mix results from different passes.
  def self.prepare(regexp, target)
    context = JsRegex::Converter::Context.new(
      case_insensitive_root: regexp.casefold?, target: target, fail_fast: false
    )
    [JsRegex::Converter.convert(Regexp::Parser.parse(regexp), context), context]
  end

  def self.convert(regexp, target:, pass: JsRegex::SecondPass)
    tree, context = prepare(regexp, target)
    options = context.required_options + (regexp.casefold? ? ['i'] : [])
    Result.new(source: pass.call(tree).to_s, options: options.uniq.sort.join, warnings: context.warnings)
  end

  def self.expected(example, global: false)
    example.inputs.map do |input|
      if global
        matches = []
        input.scan(example.regexp) { matches << match_result(input, Regexp.last_match, example.groups) }
        next matches
      end
      match = example.regexp.match(input)
      match_result(input, match, example.groups) if match
    end
  end

  def self.match_result(input, match, groups)
    # JS exec reports UTF-16 code units; Ruby reports character offsets.
    offset = input[0...match.begin(0)].encode(Encoding::UTF_16LE).bytesize / 2
    [offset, groups ? match.to_a : match[0]]
  end

  def self.actual(context, example, result, global: false)
    context.eval(<<~JS)
      (function() {
        var regexp = new RegExp(#{result.source.to_json}, #{(result.options + (global ? 'g' : '')).to_json});
        return #{example.inputs.to_json}.map(function(input) {
          regexp.lastIndex = 0;
          var matches = [];
          var match = regexp.exec(input);
          if (#{global}) {
            while (match) {
              matches.push([match.index, #{example.groups ? 'Array.from(match)' : 'match[0]'}]);
              if (match[0] === '') {
                regexp.lastIndex += regexp.unicode && input.codePointAt(regexp.lastIndex) > 0xFFFF ? 2 : 1;
              }
              match = regexp.exec(input);
            }
            return matches;
          }
          return match && [match.index, #{example.groups ? 'Array.from(match)' : 'match[0]'}];
        });
      })()
    JS
  end
end
