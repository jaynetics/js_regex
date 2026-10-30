# frozen_string_literal: true

# Integration tests for the combined second pass. Individual steps are tested
# in the specs under second_pass/.
describe JsRegex::SecondPass do
  it 'leaves trees that do not need further processing unchanged' do
    expect(/foo/).to stay_the_same
  end

  it 'keeps possessive quantifiers of the target group' do
    expect(/-(<)?+a(?(1)>)/).to\
    become(/(?:-(?:(?=((<){0}))\1)a(?:(?:>){0}))|(?:-(?:(?=((<)))\3)a(?:(?:>)))/)
      .and keep_matching('-<a>', '-a')
      .and keep_not_matching('-<a', '-<<a')
  end

  it 'checks captures made by subexpression calls in conditions' do
    expect(/\A(a)?\g<1>(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
    expect(/\A(?<x>a)?\g<x>(?(<x>)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
  end

  it 'retains earlier participating captures when checking conditions' do
    expect(/\A\g<1>(a)?(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
    expect(/\A(a)\g<1>?(?(1)b|c)\z/).to keep_matching('ab', 'aab')
      .and keep_not_matching('ac', 'aac')
  end

  it 'recognizes participating empty captures made by required calls' do
    expect(/\A(a?)?\g<1>(?(1)b|c)\z/).to keep_matching('b', 'ab', 'aab')
      .and keep_not_matching('c', 'ac', 'aac')
  end

  it 'delimits backreferences after conditional expansion renumbers them' do
    expect(/\A(a)(?(1)b)\k<1>0\z/)
      .to keep_matching('aba0')
      .and keep_not_matching('ab0', "ab\b")
  end

  it 'checks nullable captures only on the branches that reference them' do
    expect(/\A(?:(a*)|b)(?:c|\1)\z/).to keep_matching('', 'c', 'aa', 'bc')
      .and keep_not_matching('b', 'a')
  end

  it 'checks nullable captures skipped by an optional parent' do
    expect(/\A(?:(a*)b)?c(?:d|\1)\z/).to keep_matching('cd', 'bc', 'abca')
      .and keep_not_matching('c', 'abc')
  end

  it 'distinguishes skipped from empty duplicate-name captures' do
    expect(/\A(?<x>a)?(?<x>b*)?\k<x>\z/)
      .to keep_matching('', 'a', 'aa', 'bb', 'abbbb')
      .and keep_not_matching('b', 'ab')
  end

  it 'preserves greedy and lazy choices when duplicate-name candidates can match empty' do
    [/\A(?<x>a)?(?<x>a*)?\k<x>/, /\A(?<x>a)?(?<x>a|)?\k<x>/,
     /\A(?<x>a*)?(?<x>a*)??\k<x>/, /\A(?<x>a)??(?<x>a*)??\k<x>/,
     /\A(?<x>a)??(?<x>a*?)??\k<x>/].each do |regexp|
      conversions(regexp).each_value do |converted|
        %w[a aa aaa aaaa].each do |input|
          expect(eval_js("#{converted}.exec('#{input}')[0]")).to eq(regexp.match(input)[0])
        end
      end
    end
  end

  it 'preserves greedy choices when a duplicate-name candidate contains another capture' do
    regexp = /\A(?<x>a)?(?<x>(?<y>a*))?\k<x>/
    conversions(regexp).each_value do |converted|
      expect(eval_js("#{converted}.exec('aaa')[0]")).to eq('aaa')
    end
  end

  it 'uses the participating empty duplicate when its assertion succeeds' do
    conversions(/\A(?<x>a)?(?<x>(?=a))?\k<x>/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aa')[0]")).to eq('a')
    end
  end

  it 'uses the final empty iteration of a repeated duplicate-name candidate' do
    conversions(/\A(?<x>a)?(?<x>a*)*\k<x>/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aaa')[0]")).to eq('aaa')
    end
  end

  it 'rejects references to captures skipped by conditional branches' do
    expect(/\A(a)?(?(1)b|c)\1\z/).to keep_matching('aba').and keep_not_matching('c')
    expect(/\A(a)?(?(1)(b)|c)\2\z/).to keep_matching('abb').and keep_not_matching('c')
  end

  it 'requires nullable captures from conditional branches to participate' do
    expect(/\A(c)?(?(1)(a*)|b)\2\z/).to keep_matching('c', 'caa').and keep_not_matching('b')
  end

  it 'keeps nullable conditional choices after preceding greedy quantifiers' do
    conversions(/\A(a*)?(?(1)b|a)\1?/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aaab')[0]")).to eq('aaab')
      expect(eval_js("#{converted}.exec('aaa')[0]")).to eq('a')
    end
  end

  it 'remaps enclosing captures after splitting a repetition' do
    expect(/\A((a)|b)+\2\1\z/).to keep_matching('aaa', 'abab').and keep_not_matching('aa')
    expect(/\A((a)|b)+\1\2\z/).to keep_matching('aaa', 'abba').and keep_not_matching('aa')
    expect(/\A((a)?)+\1\2\z/).to keep_matching('aaa').and keep_not_matching('')
  end

  it 'preserves greedy, lazy, and bounded repetitions with retained captures' do
    [/((a)|b)+\2/, /((a)|b)+?\2/, /((a)|b)*\2/, /((a)|b)*?\2/,
     /((a)|b){2,4}\2/, /((a)|b){2,}\2/, /((a)|b){2}\2/].each do |regexp|
      conversions(regexp).each_value do |converted|
        %w[aa aba abaa baa babaa bbb].each do |input|
          match = regexp.match(input)
          expected = match && match[0]
          expect(eval_js("(#{converted}.exec('#{input}') || [null])[0]")).to eq(expected)
        end
      end
    end
  end

  it 'retains variable-width captures in bounded repetitions' do
    expect(/\A(?:(ab+)|a){1,3}\1\z/).to keep_matching('abaab', 'abbaabb')
      .and keep_not_matching('aba')
  end

  it 'allows repeated empty iterations when a finite bound prevents an endless loop' do
    expect(/\A(a*){0,2}\1\z/).to keep_matching('', 'a', 'aa', 'aaa')
    conversions(/\A(a*?){0,2}(?(1)b|a)\1?/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aba')[0]")).to eq('aba')
    end
  end

  it 'retains the last capture when a bounded loop stops after repeated empty iterations' do
    conversions(/\A(a*?){1,3}(?(1)b|a)\1?/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aba')[0]")).to eq('ab')
      expect(eval_js("#{converted}.exec('aaba')[0]")).to eq('aaba')
    end
  end

  it 'retains captures from optional parts of repeated groups' do
    expect(/\A(?:(a)?b)+\1\z/).to keep_matching('aba', 'abba', 'babba')
      .and keep_not_matching('b', 'bb', 'ab')
  end

  it 'allows iterations that skip a retained nullable capture' do
    expect(/\A(?:(a*)|b)+\1\z/).to keep_matching('', 'a', 'b', 'ab', 'aba', 'bba')
      .and keep_not_matching('c', 'abc')
  end

  it 'records a final empty iteration outside a repeated nullable capture' do
    expect(/\A(a*)*\1\z/).to keep_matching('', 'a', 'aa', 'aaa')
  end

  it 'keeps empty-match preference when a repeated body mixes greedy and lazy parts' do
    [[/\A(a*?)*\1a/, 'aaa', 'a'],
     [/\A(a*?b*)*\1/, 'b', 'b'],
     [/\A(a*?b*)*\1/, 'aa', ''],
     [/\A(a*b*?)*\1/, 'a', 'a'],
     [/\A(a*b*?)*\1\z/, 'b', 'b']].each do |regexp, input, expected|
      expect(regexp.match(input)[0]).to eq(expected)
      conversions(regexp).each_value do |converted|
        expect(eval_js("#{converted}.exec(#{input.to_json})[0]")).to eq(expected)
      end
    end
  end

  it 'uses the final empty capture when evaluating conditions after a loop' do
    conversions(/\A(a*?)*(?(1)b|a)\1?/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aba')[0]")).to eq('ab')
    end
  end

  it 'can backtrack from an empty loop ending to the previous nonempty capture' do
    expect(/\A(a*)*(?!\1)a\z/).to keep_matching('a', 'aaa')
      .and keep_not_matching('aa')
  end

  it 'retains captures through nested repetitions' do
    expect(/\A(?:(?:(a)|b)+|c)+\1\z/).to keep_matching('aa', 'aba', 'aca', 'abca')
      .and keep_not_matching('b', 'bc', 'c')
  end

  it 'retains fixed-width character sets and astral captures' do
    expect(/\A(?:([ab])|c)+\1\z/).to keep_matching('aca', 'bcb', 'abcb')
      .and keep_not_matching('c', 'acb')
    expect(/\A(?:(😋)|b)+\1\z/).to keep_matching('😋b😋').and keep_not_matching('b')
  end

  it 'checks retained captures when expanding conditionals' do
    expect(/\A(?:(a)|b)+(?(1)c|e)\z/).to keep_matching('ac', 'abc', 'be')
      .and keep_not_matching('bc')
    expect(/\A(d)?((a)|b)+\3(?(1)e|c)\z/).to keep_matching('aac', 'abac', 'daae', 'dabae')
      .and keep_not_matching('bc', 'dbe')
  end

  it 'retains variable-width captures without changing loop greediness' do
    [/\A(?:(a+)|b)+\1/, /\A(?:(a+)|b)+?\1/].each do |regexp|
      conversions(regexp).each_value do |converted|
        %w[aba aaba abaa aaaba aaaaa].each do |input|
          expect(eval_js("#{converted}.exec('#{input}')[0]")).to eq(regexp.match(input)[0])
        end
      end
    end
  end

  it 'retains variable-length runs when skipped alternatives share their character' do
    conversions(/(?:(a+)|[ab])+\1/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aba')[0]")).to eq('aba')
      expect(eval_js("#{converted}.exec('aaba')[0]")).to eq('aaba')
    end
  end

  it 'retains variable-width captures with several possible characters' do
    expect(/\A(?:(ab+)|a)+\1\z/).to keep_matching('abaab', 'abbaabb')
      .and keep_not_matching('aba', 'ababb')
    expect(/\A(?:([ab]+)|a)+\1\z/).to keep_matching('bab', 'abaab')
      .and keep_not_matching('ba')
  end

  it 'preserves loop order when the skipped branch comes before the capture' do
    conversions(/(?:a|(a(?:b)?))+\1/).each_value do |converted|
      expect(eval_js("#{converted}.exec('abaab')[0]")).to eq('abaab')
    end
  end

  it 'retains fixed-width captures when alternatives share characters or prefixes' do
    expect(/\A(?:(ab)|ba)+\1\z/).to keep_matching('abab', 'abbaab').and keep_not_matching('abba')
    conversions(/(?:(a)|ab)+\1/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aaba')[0]")).to eq('aaba')
    end
    conversions(/(?:([ab])|a)+?\1/).each_value do |converted|
      expect(eval_js("#{converted}.exec('baab')[0]")).to eq('baa')
    end
  end

  it 'retains multiple captures without changing lazy loop order' do
    conversions(/(?:(aa)|(a))+?\1\2/).each_value do |converted|
      expect(eval_js("#{converted}.exec('aaaaaa')[0]")).to eq('aaaaaa')
      expect(eval_js("#{converted}.exec('aaaaaaa')[0]")).to eq('aaaaaa')
      expect(eval_js("#{converted}.exec('aaaaaaaa')[0]")).to eq('aaaaaaaa')
    end
  end

  it 'retains captures for required references inside a branch or optional parent' do
    expect(/\A(?:(?:(a)|ab)+\1|c)\z/).to keep_matching('aa', 'aaba', 'c')
      .and keep_not_matching('aab', 'ab')
    expect(/\A(?:(?:(a)|ab)+\1)?\z/).to keep_matching('', 'aa', 'aaba')
      .and keep_not_matching('aab', 'ab')
  end

  it 'uses captures from earlier iterations inside the loop' do
    expect(/\A(?:(a)|b\1)+\z/).to keep_matching('a', 'aba', 'aaba', 'ababa')
      .and keep_not_matching('b', 'ab', 'ba')
  end

  it 'uses earlier captures inside loop branches that share a prefix' do
    expect(/\A(?:(a)|ab\1)+\z/).to keep_matching('a', 'aaba')
      .and keep_not_matching('ab', 'aba', 'aababa')
  end

  it 'evaluates conditional branches using the current iteration state' do
    expect(/\A(?:(a)|(?(1)b|c))+\z/).to keep_matching('c', 'ab', 'cab', 'ccab')
      .and keep_not_matching('b', 'bb')
    expect(/\A(?:(a)|(?(1)b|c))+\1\z/).to keep_matching('aa', 'aba', 'caba')
      .and keep_not_matching('ca', 'ba', 'aca')
  end

  it 'checks earlier participation in conditional loop branches that share a prefix' do
    expect(/\A(?:(a)|(?(1)ab|c))+\1\z/).to keep_matching('aa', 'aaba', 'caaba')
      .and keep_not_matching('c', 'ba', 'aca')
  end
end
