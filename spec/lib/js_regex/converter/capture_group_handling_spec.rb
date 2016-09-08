# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter do
  describe 'capture group handling' do
    it 'removes names from ab-named groups' do
      given_the_ruby_regexp(/(?<protocol>http|ftp)/)
      expect_js_regex_to_be(/(http|ftp)/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ftp', with_results: %w(ftp))
    end

    it 'removes names from sq-named groups' do
      given_the_ruby_regexp(/(?'protocol'http|ftp)/)
      expect_js_regex_to_be(/(http|ftp)/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ftp', with_results: %w(ftp))
    end

    it 'removes comment groups' do
      given_the_ruby_regexp(/a(?# <- this matches 'a')/)
      expect_js_regex_to_be(/a/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'a a a', with_results: %w(a a a))
    end

    it 'preserves positive lookahead groups' do
      given_the_ruby_regexp(/a(?=b)/i)
      expect_js_regex_to_be(/a(?=b)/i)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'aAb', with_results: ['A'])
    end

    it 'preserves negative lookahead groups' do
      given_the_ruby_regexp(/a(?!b)/i)
      expect_js_regex_to_be(/a(?!b)/i)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'aAb', with_results: ['a'])
    end

    it 'makes positive lookbehind groups non-lookbehind with warning' do
      given_the_ruby_regexp(/(?<=A)b/)
      expect_js_regex_to_be(/(?:A)b/)
      expect_warning
    end

    it 'drops negative lookbehind groups with warning' do
      given_the_ruby_regexp(/(?<!A)b/)
      expect_js_regex_to_be(/b/)
      expect_warning
    end

    it 'drops group-specific options with warning' do
      given_the_ruby_regexp(/a(?i-m:a)a/m)
      expect_js_regex_to_be(/a(a)a/)
      expect_warning
    end

    it 'makes conditional groups non-conditional with warning',
       if: ruby_version_at_least?('2.0') do
      given_the_ruby_regexp(Regexp.new('(a)?(?(1)b|c)'))
      expect_js_regex_to_be(Regexp.new('(a)?(b|c)'))
      expect_warning
    end

    it 'makes ab-named conditional groups non-conditional with warning',
       if: ruby_version_at_least?('2.0') do
      given_the_ruby_regexp(Regexp.new('(?<condition>a)?(?(<condition>)b|c)'))
      expect_js_regex_to_be(Regexp.new('(a)?(b|c)'))
      expect_warning
    end

    it 'makes sq-named conditional groups non-conditional with warning',
       if: ruby_version_at_least?('2.0') do
      given_the_ruby_regexp(Regexp.new("(?'condition'a)?(?('condition')b|c)"))
      expect_js_regex_to_be(Regexp.new('(a)?(b|c)'))
      expect_warning
    end

    context 'when dealing with atomic groups' do
      it 'emulates them using backreferenced lookahead groups' do
        given_the_ruby_regexp(/1(?>33|3)37/)
        expect_js_regex_to_be(/1(?=(33|3))\1(?:)37/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '1337', with_results: [])
        expect_ruby_and_js_to_match(string: '13337', with_results: ['13337'])
      end

      it 'takes into account preceding active groups for the backreference' do
        given_the_ruby_regexp(/(a(b))_1(?>33|3)37/)
        expect_js_regex_to_be(/(a(b))_1(?=(33|3))\3(?:)37/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'ab_1337', with_results: [])
        expect_ruby_and_js_to_match_string('ab_13337')
      end

      it 'isnt confused by preceding passive groups' do
        given_the_ruby_regexp(/(?:c)_1(?>33|3)37/)
        expect_js_regex_to_be(/(?:c)_1(?=(33|3))\1(?:)37/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'c_1337', with_results: [])
        expect_ruby_and_js_to_match_string('c_13337')
      end

      it 'preserves preceding number backreferences' do
        given_the_ruby_regexp(/(a)\1_1(?>33|3)37/)
        expect_js_regex_to_be(/(a)\1_1(?=(33|3))\2(?:)37/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'aa_1337', with_results: [])
        expect_ruby_and_js_to_match_string('aa_13337')
      end

      it 'drops subsequent number backreferences with warning' do
        # These are likely to be off, since they'd need to be incremented
        # depending on how many groups have been added for emulation
        # purposes between them and their target:
        #  -  /(?>aa|a)(X)\1/          would require incrementing by 1
        #  -  /(?>aa|a)(?>aa|a)(X)\1/  would require incrementing by 2
        #  -  /(?>aa|a)(X)(?>aa|a)\1/  would require incrementing by 1
        #  -  /(X)(?>aa|a)\1/          wouldn't require incrementing
        given_the_ruby_regexp(/1(?>33|3)37(a)\1/)
        expect_js_regex_to_be(/1(?=(33|3))\1(?:)37(a)/)
        expect_warning
      end
    end
  end
end
