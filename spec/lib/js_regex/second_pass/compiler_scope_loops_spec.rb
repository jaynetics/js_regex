# frozen_string_literal: true

require_relative '../../../support/second_pass_corpus'
require 'js_regex/second_pass/compiler/pipeline'

describe 'Compiler loop simplification inside forward scopes' do
  let(:compiler) { JsRegex::SecondPass::Compiler }
  before(:all) { @context = MiniRacer::Context.new(timeout: 1000) }
  after(:all) { @context.dispose }

  [/(?=((?:|a)*))\1a/, /(?=((?:|a)?))\1a/, /(?=((?:|a)*a))\1b/,
   /(?=((?:|a)*(b*)))\1\2a/, /(?!(?:|a)*a)b/,
   /(?!(a)(?:|b)*b)(a*)\2/, /(?!((?:|a)*ab))a*(?(1)b|c)/,
   /(?!(?=((?:|a)*ab))\1)a+/, /(?=((a*)*?\2a))\1/,
   /(?!(a*)*?\1a)b/].each do |regexp|
    it "preserves matches and capture arrays for #{regexp.inspect}" do
      allow(JsRegex::SecondPass).to receive(:call).and_raise('legacy pipeline invoked')
      inputs = (0..6).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
      example = SecondPassCorpus.example('scoped loops', regexp, inputs, groups: true)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end

  it 'does not retry a committed assertion or atomic group after the outside tail fails' do
    patterns = {
      /\A(?=((?:|a)*a+))a*b\1\z/ => ['aaabaaa', 'aaaba', 'aba', 'aaba'],
      /\A(?>(?:|a)*a+)(?:b|a)\z/ => ['aaab', 'aaaa', 'ab', 'aa'],
      /\A(?>(?:|a)*(?:a|ab))c\z/ => ['ac', 'abc', 'aac', 'aabc'],
      /(?>(a)(?:|b)*b)\1/ => ['aba', 'abba', 'abbba', 'baba'],
    }
    patterns.each do |regexp, inputs|
      example = SecondPassCorpus.example('commitment', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        expect(SecondPassCorpus.actual(@context, example, result)).to eq(SecondPassCorpus.expected(example)), regexp.inspect
      end
    end
  end

  it 'preserves first and global matches across body shapes, bounds, and nested scopes' do
    bodies = ['|a', 'a*?b*?', '|ab|a', 'a??b??']
    quantities = ['?', '*', '{2,3}']
    tails = ['a', 'ab', 'b*']
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    inputs += %w[aaabaaa aaaba aababaab]
    bodies.product(quantities, tails).each do |body, quantity, tail|
      inner = '(?:' + body + ')' + quantity + tail
      patterns = [
        ['(?=(' + inner + '))\\1b?', true],
        ['(?!(' + inner + '))a*(?(1)b|a)', true],
        ['(?>' + inner + ')ab', false],
        ['(?=(?=(' + inner + '))\\1)\\1', true],
        ['(?!(?=(' + inner + '))\\1)a+', true],
      ]
      patterns.each do |source, groups|
        regexp = Regexp.new(source)
        example = SecondPassCorpus.example('scoped loop matrix', regexp, inputs, groups: groups)
        result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
        [false, true].each do |global|
          expected = SecondPassCorpus.expected(example, global: global)
          actual = SecondPassCorpus.actual(@context, example, result, global: global)
          differences = inputs.each_index.select { |index| actual[index] != expected[index] }
          expect(differences.take(5).map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty,
            "#{regexp.inspect}, global: #{global}"
        end
      end
    end
  end

  it 'lowers closed nullable capture loops inside forward scopes' do
    bodies = ['a*?', '|a', 'a*?b*?']
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    bodies.product(['*', '+', '*?', '+?'], ['a', 'ab', 'b*']).each do |body, quantity, tail|
      inner = '(' + body + ')' + quantity
      patterns = ['(?=(' + inner + '\\2' + tail + '))\\1',
                  '(?!(' + inner + '\\2' + tail + '))a+',
                  '(?>' + inner + '\\1' + tail + ')ab?',
                  '(?!(?=(' + inner + '\\2' + tail + '))\\1)a+']
      patterns.each do |source|
        regexp = Regexp.new(source)
        example = SecondPassCorpus.example('closed scoped capture loop', regexp, inputs)
        JsRegex::Target::SUPPORTED.each do |target|
          result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
          [false, true].each do |global|
            expected = SecondPassCorpus.expected(example, global: global)
            actual = SecondPassCorpus.actual(@context, example, result, global: global)
            differences = inputs.each_index.select { |index| actual[index] != expected[index] }
            expect(differences.take(5).map { |index| [inputs[index], expected[index], actual[index]] }).to be_empty,
              "#{regexp.inspect}, #{target}, global: #{global}"
          end
        end
      end
    end
  end

  it 'keeps capture-dependent suffixes outside the capture guard rule' do
    [/((a*?)*\2)\1b/, /((a*?)*\2)(b)\1/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      children = tree.children
      expect { compiler.call(tree) }.to raise_error(compiler::Unsupported), regexp.inspect
      expect(tree.children).to equal(children)
    end
  end

  it 'checks independent suffixes before committing an empty loop ending inside a capture' do
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    ['a*?', 'a*?b*?', 'a*b*', '|a'].product(['*', '+', '*?', '+?'], ['b', 'ab', '(?=b)b']).each do |body, quantity, tail|
      inner = '((' + body + ')' + quantity + '\\2)'
      [inner + tail, 'a' + inner + tail, '(?=' + inner + tail + ')\\1',
       '(?!' + inner + tail + ')b+'].each do |source|
        regexp = Regexp.new(source)
        example = SecondPassCorpus.example('capture suffix guard', regexp, inputs)
        JsRegex::Target::SUPPORTED.each do |target|
          result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
          [false, true].each do |global|
            expect(SecondPassCorpus.actual(@context, example, result, global: global))
              .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
          end
        end
      end
    end
  end

  it 'keeps lazy alternatives available and permits outside tails that always succeed' do
    [/((a*?)*?\2)b/, /((a*?)*\2)b?/].each do |regexp|
      example = SecondPassCorpus.example('outside continuation', regexp, %w[ab aab aaab b a ba])
      result = SecondPassCorpus.convert(regexp, target: JsRegex::Target::ES2018, pass: compiler)
      [false, true].each do |global|
        expect(SecondPassCorpus.actual(@context, example, result, global: global))
          .to eq(SecondPassCorpus.expected(example, global: global)), regexp.inspect
      end
    end
  end

  it 'retains unsupported escaping values and reference-bearing loop bodies' do
    [/(?=(a*?)*?a)\1/, /(?=(a))(?:(?:|\1))*\1/].each do |regexp|
      tree, = SecondPassCorpus.prepare(regexp, JsRegex::Target::ES2018)
      children = tree.children
      expect { compiler.call(tree) }.to raise_error(compiler::Unsupported), regexp.inspect
      expect(tree.children).to equal(children)
    end
  end

  it 'keeps closed nullable choices and their continuations inside forward scopes' do
    inputs = (0..7).flat_map { |length| %w[a b].repeated_permutation(length).map(&:join) }
    ['a*', 'a*?', '|a'].product(['?', '??', '|b', 'b|'], ['b', '\\k<n>b', '(?!\\k<n>)a']).each do |body, form, present|
      capture = '(?<n>' + body + ')'
      choice = case form
               when '|b' then '(?:' + capture + '|b)'
               when 'b|' then '(?:b|' + capture + ')'
               else capture + form
               end
      inner = choice + '(?(<n>)' + present + '|a)'
      patterns = ['(?=' + inner + ')a*b', '(?!' + inner + ')b+',
                  '(?>' + inner + ')ab?', '(?=(?<out>' + inner + '))\\k<out>']
      patterns.each do |source|
        regexp = Regexp.new(source)
        example = SecondPassCorpus.example('closed scoped choice', regexp, inputs)
        JsRegex::Target::SUPPORTED.each do |target|
          result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
          [false, true].each do |global|
            expect(SecondPassCorpus.actual(@context, example, result, global: global))
              .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
          end
        end
      end
    end
  end

  it 'keeps state transitions and disjoint lazy runs inside their committed scopes' do
    inputs = (0..7).flat_map { |length| %w[a b c].repeated_permutation(length).map(&:join) }
    bodies = ['(?:(a)|(?(1)b|c))+\\1', '(?:(a)|(b))+?\\1\\2',
              '(?:(a+)|(b+))+?\\1\\2', '(?:(a+)|ab)+?(?(1)c|a)']
    bodies.product(['(?=%s)a*b*', '(?!%s)a+b*', '(?>%s)ab?', '(?=(?>%s))a+b*']).each do |body, wrapper|
      regexp = Regexp.new(format(wrapper, body))
      example = SecondPassCorpus.example('committed loop states', regexp, inputs)
      JsRegex::Target::SUPPORTED.each do |target|
        result = SecondPassCorpus.convert(regexp, target: target, pass: compiler)
        [false, true].each do |global|
          expect(SecondPassCorpus.actual(@context, example, result, global: global))
            .to eq(SecondPassCorpus.expected(example, global: global)), "#{regexp.inspect}, #{target}, global: #{global}"
        end
      end
    end
  end
end
