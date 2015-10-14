# encoding: utf-8

require 'spec_helper'

describe JsRegex::Converter do
  describe 'literal handling' do
    context 'when the literal is a newline' do
      it 'converts it into a newline escape' do
        given_the_ruby_regexp(/
/)
        expect_js_regex_to_be(/\n/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: "a\nb", with_results: ["\n"])
      end
    end

    context 'when the literal is anything but a newline' do
      it 'lets the literal pass through' do
        given_the_ruby_regexp(/aü_1>!/)
        expect_js_regex_to_be(/aü_1>!/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: 'aü_1>!', with_results: %w(aü_1>!))
      end

      it 'does not add escapes to \\n' do
        given_the_ruby_regexp(/\\n/)
        expect_js_regex_to_be(/\\n/)
        expect_no_warnings
        expect_ruby_and_js_to_match(string: '\\n', with_results: %w(\\n))
      end
    end
  end
end
