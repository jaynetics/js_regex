# frozen_string_literal: true

# Integration tests for the combined second pass. Individual steps are tested
# in the specs under second_pass/.
describe JsRegex::SecondPass do
  it 'leaves trees that do not need further processing unchanged' do
    expect(/foo/).to stay_the_same
  end

  it 'leaves bounded backreferences without captured groups intact' do
    expect(/\A(a)\1{2}0\z/).to become(/^(a)\1{2}0$/)
      .and keep_matching('aaa0')
      .and keep_not_matching('aa0', 'aaaa0')
  end

  it 'keeps possessive quantifiers of the target group' do
    regexp = /-(<)?+a(?(1)>)/
    expect(regexp).not_to generate_warning
    expect(regexp).to keep_capturing('-<a>' => '-<a>', '-a' => '-a', '-<a' => nil, '-<<a' => nil)
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

  # Duplicate-name backreferences were fixed in Ruby 3.1.3: https://bugs.ruby-lang.org/issues/18631
  it 'preserves greedy and lazy choices when duplicate-name candidates can match empty',
    if: (Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('3.1.3')) do
    [/\A(?<x>a)?(?<x>a*)?\k<x>/, /\A(?<x>a)?(?<x>a|)?\k<x>/,
     /\A(?<x>a*)?(?<x>a*)??\k<x>/, /\A(?<x>a)??(?<x>a*)??\k<x>/,
     /\A(?<x>a)??(?<x>a*?)??\k<x>/].each do |regexp|
      examples = %w[a aa aaa aaaa].to_h { |str| [str, regexp.match(str)[0]] }
      expect(regexp).to keep_capturing(examples)
    end
  end

  it 'preserves greedy choices when a duplicate-name candidate contains another capture' do
    expect(/\A(?<x>a)?(?<x>(?<y>a*))?\k<x>/).to keep_capturing('aaa' => 'aaa')
  end

  it 'uses the participating empty duplicate when its assertion succeeds' do
    expect(/\A(?<x>a)?(?<x>(?=a))?\k<x>/).to keep_capturing('aa' => 'a')
  end

  it 'uses the final empty iteration of a repeated duplicate-name candidate' do
    expect(/\A(?<x>a)?(?<x>a*)*\k<x>/).to keep_capturing('aaa' => 'aaa')
  end

  it 'rejects references to captures skipped by conditional branches' do
    expect(/\A(a)?(?(1)b|c)\1\z/).to keep_matching('aba').and keep_not_matching('c')
    expect(/\A(a)?(?(1)(b)|c)\2\z/).to keep_matching('abb').and keep_not_matching('c')
  end

  it 'requires nullable captures from conditional branches to participate' do
    expect(/\A(c)?(?(1)(a*)|b)\2\z/).to keep_matching('c', 'caa').and keep_not_matching('b')
  end

  it 'keeps discarded conditional captures unmatched after nullable expansion' do
    expect(/\A(a*)?(?(1)b|(c(d)))(?(3)e|f)\z/)
      .to keep_matching('bf', 'aabf', 'cde')
      .and keep_not_matching('be', 'cdf', 'aabe')
    expect(/\A(a*)?(?(1)(b))(c)\3\z/)
      .to keep_matching('bcc', 'aabcc', 'cc')
      .and keep_not_matching('bc', 'c', 'aacc')
  end

  it 'keeps nullable conditional choices after preceding greedy quantifiers' do
    expect(/\A(a*)?(?(1)b|a)\1?/).to keep_capturing('aaab' => 'aaab', 'aaa' => 'a')
  end

  it 'remaps enclosing captures after splitting a repetition' do
    expect(/\A((a)|b)+\2\1\z/).to keep_matching('aaa', 'abab').and keep_not_matching('aa')
    expect(/\A((a)|b)+\1\2\z/).to keep_matching('aaa', 'abba').and keep_not_matching('aa')
    expect(/\A((a)?)+\1\2\z/).to keep_matching('aaa').and keep_not_matching('')
  end

  it 'preserves greedy, lazy, and bounded repetitions with retained captures' do
    [/((a)|b)+\2/, /((a)|b)+?\2/, /((a)|b)*\2/, /((a)|b)*?\2/,
     /((a)|b){2,4}\2/, /((a)|b){2,}\2/, /((a)|b){2}\2/].each do |regexp|
      examples = %w[aa aba abaa baa babaa bbb].map do |input|
        [input, regexp.match(input) { |match| match[0] }]
      end.to_h
      expect(regexp).to keep_capturing(examples)
    end
  end

  it 'retains variable-width captures in bounded repetitions' do
    expect(/\A(?:(ab+)|a){1,3}\1\z/).to keep_matching('abaab', 'abbaabb')
      .and keep_not_matching('aba')
  end

  it 'allows repeated empty iterations when a finite bound prevents an endless loop' do
    expect(/\A(a*){0,2}\1\z/).to keep_matching('', 'a', 'aa', 'aaa')
    expect(/\A(a*?){0,2}(?(1)b|a)\1?/).to keep_capturing('aba' => 'aba')
  end

  it 'retains the last capture when a bounded loop stops after repeated empty iterations' do
    expect(/\A(a*?){1,3}(?(1)b|a)\1?/).to keep_capturing('aba' => 'ab', 'aaba' => 'aaba')
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
      expect(regexp).to keep_capturing(input => expected)
    end
  end

  it 'uses the final empty capture when evaluating conditions after a loop' do
    expect(/\A(a*?)*(?(1)b|a)\1?/).to keep_capturing('aba' => 'ab')
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
      examples = %w[aba aaba abaa aaaba aaaaa].to_h { |str| [str, regexp.match(str)[0]] }
      expect(regexp).to keep_capturing(examples)
    end
  end

  it 'retains variable-length runs when skipped alternatives share their character' do
    expect(/(?:(a+)|[ab])+\1/).to keep_capturing('aba' => 'aba', 'aaba' => 'aaba')
  end

  it 'retains variable-width captures with several possible characters' do
    expect(/\A(?:(ab+)|a)+\1\z/).to keep_matching('abaab', 'abbaabb')
      .and keep_not_matching('aba', 'ababb')
    expect(/\A(?:([ab]+)|a)+\1\z/).to keep_matching('bab', 'abaab')
      .and keep_not_matching('ba')
  end

  it 'preserves loop order when the skipped branch comes before the capture' do
    expect(/(?:a|(a(?:b)?))+\1/).to keep_capturing('abaab' => 'abaab')
  end

  it 'retains fixed-width captures when alternatives share characters or prefixes' do
    expect(/\A(?:(ab)|ba)+\1\z/).to keep_matching('abab', 'abbaab').and keep_not_matching('abba')
    expect(/(?:(a)|ab)+\1/).to keep_capturing('aaba' => 'aaba')
    expect(/(?:([ab])|a)+?\1/).to keep_capturing('baab' => 'baa')
  end

  it 'retains multiple captures without changing lazy loop order' do
    expect(/(?:(aa)|(a))+?\1\2/).to keep_capturing(
      'aaaaaa' => 'aaaaaa', 'aaaaaaa' => 'aaaaaa', 'aaaaaaaa' => 'aaaaaaaa'
    )
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

  it 'stops a nullable alternative loop at the preferred empty iteration' do
    expect(/(?:(a*)|b)+\1/).to keep_capturing('b' => '', 'ab' => 'a', 'ba' => '')
  end

  it 'retains both variable-width captures in lazy loops' do
    expect(/(?:(a+)|(b+))+?\1\2/).to keep_capturing('abab' => 'abab', 'abaab' => 'abaab')
    expect(/\A(?:(a+)|(b+))+?\1\2\z/).to keep_matching('abab').and keep_not_matching('ab')
  end

  it 'checks loop participation without moving the conditional ahead of the loop' do
    expect(/(?:(a)|b)+(?(1)c|a)/).to keep_capturing('bac' => 'bac')
  end

  it 'keeps optional capture preference when selecting a conditional branch' do
    expect(/(a)?(?(1)b|a)/).to keep_capturing('ab' => 'ab')
    expect(/(a)??(?(1)b|a)/).to keep_capturing('ab' => 'a')
  end

  it 'tries later lazy iterations before splitting an earlier capture' do
    patterns = [/(?:(a+)|(b+))+?\1\2/, /(?:(a+)|(b+))*?\1\2/,
                /(?:(a+)|(b+))+?\2\1/, /((a+)|(b+))+?\2\3/]
    patterns.each do |regexp|
      examples = %w[abbabab baaabab baabaab baabab abaabab baababa aabbaaabbb].to_h do |input|
        [input, regexp.match(input) { |match| match[0] }]
      end
      expect(regexp).to keep_capturing(examples)
    end
  end

  it 'distinguishes no iteration from a final empty capture in conditional loops' do
    expect(/(?:(a*)|b)+(?(1)c|a)/).to keep_capturing('bac' => 'bac', 'baac' => 'baac')
      .and keep_not_matching('a', 'aa', 'ab')
  end

  it 'commits to the first matching duplicate-name reference' do
    expect(/(?<n>x)(?<n>xx)\k<n>x/).to keep_not_matching('xxxxx')
      .and keep_capturing('xxxxxx' => ['xxxxxx', 'x', 'xx'])
    expect(/(?<n>x)(?<n>xx)\k<n>\k<n>x/).to keep_not_matching('xxxxxx', 'xxxxxxx')
      .and keep_matching('xxxxxxxx')
  end

  it 'can try an older named capture when the newer value does not match' do
    expect(/(?<n>a)(?<n>b)\k<n>/).to keep_capturing('aba' => ['aba', 'a', 'b'], 'abb' => ['abb', 'a', 'b'])
    expect(/(?<n>xx)(?<n>x)??\k<n>/).to keep_capturing('xxxxx' => 'xxxx')
  end

  it 'commits to the first matching value among three captures with the same name' do
    expect(/(?<n>a)(?<n>aa)(?<n>b)\k<n>a/).to keep_not_matching('aaabaa')
      .and keep_capturing('aaabaaa' => ['aaabaaa', 'a', 'aa', 'b'], 'aaabba' => ['aaabba', 'a', 'aa', 'b'])
  end

  it 'keeps the final empty capture when a lazy character run is collapsed' do
    expect(/((a*)+?\2)\1/).to keep_capturing('aaaa' => ['aaaa', 'aa', ''])
  end

  it 'retains participation for conditions after overlapping lazy alternatives' do
    expect(/(?:(a)|ab)+?(?(1)c|a)/).to keep_capturing('aabc' => 'aabc', 'aaba' => 'aba')
    expect(/(?:(a+)|ab)+?(?(1)c|a)/).to keep_capturing('aabc' => 'aabc', 'aaba' => 'aba')
  end

  it 'tries an optional reference before a skipping iteration of an overlapping lazy loop' do
    expect(/(?:(a)|ab)+?\1?/).to keep_capturing('ab' => ['a', 'a'])
    expect(/(?:(a+)|ab)+?\1?/).to keep_capturing('ab' => ['a', 'a'])
  end

end
