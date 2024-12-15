#
#
#
# WARNING: Some of the examples below contain literal tabs.
# Make sure that your IDE doesn't replace them with spaces.
#
#
#

require 'spec_helper'

describe LangRegex::Converter::FreespaceConverter do
  context 'when extended mode is set' do
    it 'drops comments and whitespace' do
      expect(/Multiple    #   comment 1
                             Comments!   #   comment 2
                            /x).to\
      become(/MultipleComments!/)
        .and keep_matching('MultipleComments!',
                           with_results: ['MultipleComments!'])
    end

    it 'drops whitespace literals' do
      expect(/	Unescaped  Whitespace!	/x).to\
      become(/UnescapedWhitespace!/)
        .and keep_matching('UnescapedWhitespace!',
                           with_results: ['UnescapedWhitespace!'])
    end

    it 'drops whitespace in extended-mode groups' do
      expect(/ He(?x: ll )o /).to\
      become(/ He(?:ll)o /)
        .and keep_matching(' Hello ', with_results: [' Hello '])
    end

    it 'drops whitespace after extended-mode switches' do
      expect(/ He ll(?x) o /).to\
      become(/ He llo/)
        .and keep_matching(' He llo', with_results: [' He llo'])
    end

    it 'does not drop escaped whitespace literals' do
      expect(/Escaped\	Whitespace\ !/x).to\
      become(/Escaped\tWhitespace !/)
        .and keep_matching('Escaped	Whitespace !',
                           with_results: ['Escaped	Whitespace !'])
    end

    it 'does not drop whitespace in non-extended-mode groups' do
      expect(/ He(?-x: ll )o /x).to\
      become(/He(?: ll )o/)
        .and keep_matching('He ll o', with_results: ['He ll o'])
    end

    it 'does not drop whitespace after non-extended-mode switches' do
      expect(/ He ll(?-x) o /x).to\
      become(/Hell o /)
        .and keep_matching('Hell o ', with_results: ['Hell o '])
    end
  end

  context 'when extended mode is not specified' do
    it 'does not drop comments and whitespace' do
      expect(/
Multiple  # comment 1
Comments! # comment 2
/).to\
      become(/\nMultiple  # comment 1\nComments! # comment 2\n/)
    end

    it 'does not drop whitespace literals' do
      expect(/	Unescaped  Whitespace!	/).to\
      become(/\tUnescaped  Whitespace!\t/)
        .and keep_matching('	Unescaped  Whitespace!	',
                           with_results: ['	Unescaped  Whitespace!	'])
    end

    it 'does not drop escaped whitespace literals' do
      expect(/Escaped\	Whitespace\ !/).to\
      become(/Escaped\tWhitespace !/)
        .and keep_matching('Escaped	Whitespace !',
                           with_results: ['Escaped	Whitespace !'])
    end
  end
end
