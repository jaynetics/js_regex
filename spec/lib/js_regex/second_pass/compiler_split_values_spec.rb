# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler split capture values' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  patterns = [/(a*(b*)?)\2?/, /(a*(a*)?)\2?a/, /(a*(b*)?)\1\2?/,
              /(a*(b*)??)\1\2?/, /((a*(b*)?)c)\1\3?/,
              /(a*(b*)?)?(?(1)c|a)\2?/, /(a*(b*)?)??(?(1)c|a)\2?/,
              /(a*(b*)?)(?=\1)\2?/, /(?!(a*(b*)?)c)\1?\2?/,
              /\A(a*(a*)?){2,4}\1\2?\z/, /(a*(b*)?){0,3}(?(1)c|a)\2?/,
              /\A(a*(b*)?){1,3}\1\z/, /\A(a*(b*)?){1,3}?\1a\z/,
              /(a*(b*)?){1,3}(?!\1)a/, /(a*(b*)?){1,3}?(?(1)b|a)/,
              /(a*(b*)?){1,3}(?(1)b|a)\1?/]
  patterns.each do |regexp|
    it "preserves prefix backtracking and reconstructed values for #{regexp.inspect}" do
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('split value', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        actual = SecondPassCorpus.actual(@context, example, result)
        expected = SecondPassCorpus.expected(example)
        differences = inputs.each_index.select { |index| actual[index] != expected[index] }
        expect(differences.take(10).map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty,
          "#{regexp.inspect} on #{target}"
      end
    end
  end

  it 'does not split values observed before the capture closes' do
    [/(a*(b*)?(?(1)c|d))\2?/, /(a*(b*)?\1)\2?/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      expression = compiler::Importer.call(tree)
      expect(compiler::SplitCaptureValues.call(expression)).to equal(expression)
    end
  end

  [/(?<x>a*(?<y>b*)?)(?<x>c)\k<x>\k<y>?/,
   /(?<x>a*(?<y>b*)?)(?<x>c)?\k<x>\k<y>?/,
   /(?<x>a*(?<y>b*)?)(?<x>a*)\k<x>\k<y>?a/,
   /(?<x>a*(?<y>b*)?)(?<x>a*)?\k<x>\k<y>?b/,
   /(?<x>a*(?<y>b*)?)\g<x>\k<x>\k<y>?/,
   /(?<x>a*(?<y>b*)?)\g<x>?\k<x>\k<y>?/,
   /\A(?<x>a*(?<y>b*)?)\g<x>?\k<x>\k<y>?\z/,
   /(?<x>a*?(?<y>b*?)?)(?<x>c)?\k<x>/,
   /(?<x>a*(?<y>b*)?){1,3}\k<x>\k<y>?/,
   /(?<x>a*(?<y>b*)?)(?<x>c){0,2}\k<x>\k<y>?/].each do |regexp|
    it "selects complete composite values for #{regexp.inspect}" do
      if regexp.named_captures['x'].length > 1 && Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1.3')
        skip 'Ruby oracle predates the duplicate-name fix: https://bugs.ruby-lang.org/issues/18631'
      end
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('composite selection', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'preserves duplicate-name commitment independently of old Ruby oracle bugs' do
    # Verified with Ruby 4: pre-3.1.3 engines reject an empty fallback or revisit
    # older duplicate-name values after a matching value's continuation fails.
    cases = {
      /(?<x>a*(?<y>b*)?)(?<x>c)\k<x>\k<y>?/ => ['c', 'c'],
      /(?<x>a*(?<y>b*)?)(?<x>c)?\k<x>\k<y>?/ => ['c', 'c'],
      /(?<x>a*(?<y>b*)?)(?<x>a*)\k<x>\k<y>?a/ => ['baaaba', 'baaaba'],
      /(?<x>a*(?<y>b*)?)(?<x>a*)?\k<x>\k<y>?b/ => ['baaabb', 'baaabb'],
      /(?<x>a*?(?<y>b*?)?)(?<x>c)?\k<x>/ => ['c', 'c'],
      /(?<x>a*(?<y>b*)?)(?<x>c){0,2}\k<x>\k<y>?/ => ['c', 'c'],
    }
    cases.each do |regexp, (input, match)|
      example = SecondPassCorpus.example('fixed duplicate-name oracle', regexp, [input])
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq([[0, match]]), regexp.inspect
        if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.3')
          expect(SecondPassCorpus.expected(example)).to eq([[0, match]]), regexp.inspect
        end
      end
    end
  end

  it 'reconstructs raw value checks while allowing a fully absent value to match empty' do
    regexp = /\A(a*(b*)?)?(?(1)\1|)\2?\z/
    inputs = (0..6).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    example = SecondPassCorpus.example('split raw value', regexp, inputs)
    JsRegex::Target::SUPPORTED.each do |target|
      tree, = SecondPassCorpus.prepare(regexp, target)
      replace = lambda do |node|
        next if node.instance_of?(String)
        if node.type == :conditional
          node.update(type: :capture_check, children: ["\\#{node.reference}"])
        else
          node.children.each { |child| replace.call(child) }
        end
      end
      replace.call(tree)
      result = SecondPassCorpus::Result.new(source: compiler.call(tree).to_s, options: '', warnings: [])
      expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example))
    end
  end
end
