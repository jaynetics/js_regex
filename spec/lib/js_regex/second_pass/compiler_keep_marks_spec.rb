# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe JsRegex::SecondPass::Compiler do
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  it 'preserves the final keep mark and the start of the returned match' do
    [/a\Kb/, /a\Kb\Kc/, /a\Kb|c\Ka/, /\Ka/, /a\K/, /\K/, /(a)\K\1/,
     /(a)\1\Kb/, /(a)?\1\Kb/, /(ab)\1\Kc/, /(a)(b)\2\1\Kc/,
     /(?<n>a)(?<n>b)\k<n>\Kc/, /a{2}\Kb/, /a\Kb\Kc|ab\Ka/].each do |regexp|
      inputs = (0..5).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('keep marks', regexp, inputs, groups: true)
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: described_class)
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end

  it 'rejects keep marks whose lookbehind would change search or backtracking order' do
    [/a+\Ka/, /a+?\Ka/, /a\Kba|ab/,
     /(?:(a)|(a))\K(?(1)c|a)/, /([ab]){2}\K\1/, /(a){2}\Kb/i].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      children = tree.children
      expect { described_class.call(tree) }.to raise_error(described_class::Unsupported, /keep-mark prefixes/)
      expect(tree.children).to equal(children)
    end
  end

  it 'leaves unsupported keep-mark warnings under converter control' do
    [JsRegex::Target::ES2009, JsRegex::Target::ES2015].each do |target|
      result = SecondPassCorpus.convert(/a\Kb/, target: target, pass: described_class)
      expect(result.source).to eq('ab')
      expect(result.warnings).to eq(JsRegex.new(/a\Kb/, target: target).warnings)
    end
    result = SecondPassCorpus.convert(/a(b\Kc)d/, target: JsRegex::Target::ES2018, pass: described_class)
    expect(result.source).to eq('a(bc)d')
    expect(result.warnings).to eq(JsRegex.new(/a(b\Kc)d/, target: JsRegex::Target::ES2018).warnings)
  end

  [/a\Kb|c/, /c|a\Kb\Kc/, /aa\Kb|a\Kc/, /a{2}\Kb|c/,
   /a\Kbc|b/, /b|a\Kb/, /ab|a\Kbc/, /a\Kb\Kc|d/,
   /c|a\Kb|aa\Kc/, /a\Kb|c|d\Ke/, /(a)\Kb|c/,
   /ab\K(c)|c/, /a\K(b)|b/, /a\K(b){2}|c/].each do |pattern|
    [0, Regexp::IGNORECASE].each do |flags|
      regexp = Regexp.new(pattern.source, flags)
      it "preserves first and global matches for mixed keep offsets in #{regexp.inspect}" do
        inputs = (0..5).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
        inputs += %w[abcabc abacba bbaabcabc abcabcabc aabcaac bac abcd abcde de cababcde]
        inputs += inputs.map(&:upcase) + %w[aBcABc AbCaBc aABcaAC]
        example = SecondPassCorpus.example('mixed keep offsets', regexp, inputs, groups: true)
        result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: described_class)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, global: #{global}"
        end
      end
    end
  end

  it 'rejects literal overlap that changes priority or reuses a consumed prefix' do
    [/a\Kba|ab/, /b|a\Kbc/, /a|a\Kb/, /a\Ka|b/, /a\K|b/,
     /a\Kb|/, /a\Kbc|AB/i, /a\Kbc|AB/, /é\Ka|b/,
     /(c)|ab\Kc/, /c|ab\K(c)/, /b|a\K(b)/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      children = tree.children
      expect { described_class.call(tree) }.to raise_error(described_class::Unsupported, /keep-mark prefixes/), regexp.inspect
      expect(tree.children).to equal(children)
    end
  end
end
