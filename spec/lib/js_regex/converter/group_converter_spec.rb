require 'spec_helper'

describe LangRegex::Converter::GroupConverter do
  it 'preserves capturing groups' do
    expect(/(abc)/).to stay_the_same.and keep_matching('abc', with_results: %w[abc])
  end

  it 'sets Node#reference for SecondPass lookups' do
    group = Regexp::Parser.parse(/(abc)/)[0]

    result = LangRegex::JsRegex.js_converter.convert(group)

    expect(result).to be_a LangRegex::Node
    expect(result.type).to eq(:captured_group)
    expect(result.reference).to eq(1)
  end

  it 'preserves passive groups' do
    expect(/(?:abc)/).to stay_the_same.and keep_matching('abc', with_results: %w[abc])
  end

  it 'removes names from ab-named groups', targets: [ES2009, ES2015] do
    expect(/(?<protocol>http|ftp)/).to\
    become(/(http|ftp)/).and keep_matching('ftp', with_results: %w[ftp])
  end

  it 'keeps names for ab-named groups on ES2018+', targets: [ES2018] do
    expect(/(?<protocol>http|ftp)/)
      .to stay_the_same
      .and keep_matching('ftp', with_results: %w[ftp])
  end

  it 'removes names from sq-named groups', targets: [ES2009, ES2015] do
    expect(/(?'protocol'http|ftp)/).to\
    become(/(http|ftp)/).and keep_matching('ftp', with_results: %w[ftp])
  end

  it 'converts sq-names to ab-nameson ES2018+', targets: [ES2018] do
    expect(/(?'protocol'http|ftp)/).to\
    become(/(?<protocol>http|ftp)/).and keep_matching('ftp', with_results: %w[ftp])
  end

  it 'removes comment groups' do
    expect(/a(?# <- this matches 'a')/).to\
    become(/a/).and keep_matching('a a a', with_results: %w[a a a])
  end

  it 'drops switch groups without warning' do
    expect(/a(?m-x)a/).to\
    become(/aa/).and keep_matching('aa', with_results: %w[aa])
  end

  it 'drops encoding options without warning' do
    expect(/1(?u:2)3(?a)4(?d:)/).to\
    become(/1(?:2)34(?:)/)
  end

  it 'works following positive lookbehind assertions', targets: [ES2009, ES2015] do
    expect(/(?<=A)(abc)/).to\
    become(/(?:A)(abc)/).with_warning
  end

  it 'works following positive lookbehind assertions on ES2018+', targets: [ES2018] do
    expect(/(?<=A)(abc)/)
      .to stay_the_same
      .and keep_matching('abc Aabc Aabc', with_results: %w[abc abc])
  end

  it 'works following negative lookbehind assertions', targets: [ES2009, ES2015] do
    expect(/(?<!A)(abc)/).to\
    become(/(abc)/).with_warning
  end

  it 'works following negative lookbehind assertions on ES2018+', targets: [ES2018] do
    expect(/(?<!A)(abc)/)
      .to stay_the_same
      .and keep_matching('abc Aabc Aabc', with_results: %w[abc])
  end

  it 'opens passive groups for unknown group heads' do
    expect([:group, :unknown]).to be_dropped_with_warning
  end

  context 'when dealing with atomic groups' do
    # Atomicity is emulated using backreferenced lookahead groups:
    # http://instanceof.me/post/52245507631
    # regex-emulate-atomic-grouping-with-lookahead
    it 'emulates them using backreferenced lookahead groups' do
      expect(/1(?>33|3)37/).to\
      become(/1(?=(33|3))\1(?:)37/)
        .and keep_matching('13337', with_results: ['13337'])
        .and keep_not_matching('1337')
    end

    it 'can handle multiple atomic groups' do
      expect(/(?>33|3)(?:3)(?>33|3)3/).to\
      become(/(?=(33|3))\1(?:)(?:3)(?=(33|3))\2(?:)3/)
        .and keep_matching('333333', with_results: ['333333'])
        .and keep_not_matching('3333')
    end

    it 'can handle atomic groups nested in non-atomic groups' do
      expect(/1((?>33|3))37/).to\
      become(/1((?=(33|3))\2(?:))37/)
        .and keep_matching('13337')
        .and keep_not_matching('1337')
    end

    it 'makes atomic groups nested in atomic groups non-atomic with warning' do
      expect(/1(?>(?>33|3))37/).to\
      become(/1(?=((?:33|3)))\1(?:)37/).with_warning('nested atomic group')
    end

    it 'takes into account preceding active groups for the backreference' do
      expect(/(a(b))_1(?>33|3)37/).to\
      become(/(a(b))_1(?=(33|3))\3(?:)37/)
        .and keep_matching('ab_13337')
        .and keep_not_matching('ab_1337')
    end

    it 'isnt confused by preceding passive groups' do
      expect(/(?:c)_1(?>33|3)37/).to\
      become(/(?:c)_1(?=(33|3))\1(?:)37/)
        .and keep_matching('c_13337')
        .and keep_not_matching('c_1337')
    end

    it 'isnt confused by preceding lookahead groups' do
      expect(/(?=c)_1(?>33|3)37/).to\
      become(/(?=c)_1(?=(33|3))\1(?:)37/)
        .and keep_not_matching('c_1337')
    end

    it 'isnt confused by preceding negative lookahead groups' do
      expect(/(?!=x)_1(?>33|3)37/).to\
      become(/(?!=x)_1(?=(33|3))\1(?:)37/)
        .and keep_matching('c_13337')
        .and keep_not_matching('c_1337')
    end
  end

  context 'when dealing with absence groups',
    if: (Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.4.1')) do

    it 'converts simple cases to complimentary alternations' do
      expect(Regexp.new('1(?~23)4')).to\
      become(/1(?:(?:.|\n){,1}|(?:(?!23)(?:.|\n))*)4/)
        .and keep_matching('14', '124', '134', '12224', '13334')
        .and keep_not_matching('1234', '12234')
    end

    it 'can handle fixed quantifications' do
      expect(Regexp.new('A(?~\d{4})Z')).to\
      become(/A(?:(?:.|\n){,3}|(?:(?!\d{4})(?:.|\n))*)Z/)
        .and keep_matching('AZ', 'A123Z', 'A12X34Z')
        .and keep_not_matching('A1234Z')
    end

    it 'drops variably quantified cases with warning' do
      expect(Regexp.new('1(?~2+)3')).to\
      become(/13/).with_warning('variable-length absence group content')
    end

    it 'drops other variable length cases with warning' do
      expect(Regexp.new('1(?~2|22)3')).to\
      become(/13/).with_warning('variable-length absence group content')
    end

    it 'converts unmatchable cases to an unmatchable group' do
      expect(Regexp.new('1(?~)2')).to\
      become(/1(?!)2/).and keep_not_matching('12', '1x2')
    end
  end
end
