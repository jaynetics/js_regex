# encoding: utf-8

require 'spec_helper'

describe JsRegex do
  it 'can handle a complex email validation regex' do
    regex = /[a-z0-9!$#%&'*+=?^_\`\{|\}~-]+
             (?:\.[a-z0-9!$#%&\'*+=?^_\`\{|}~-]+)*@
             (?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+
             (?:[A-Z]{2}|com|org|net|edu|gov|mil|
             biz|info|mobi|name|aero|asia|jobs|museum)\b/xi
    given_the_ruby_regexp(regex)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'a@b me@s-w.com x.y@place.edu #ö+.',
                                with_results: %w(me@s-w.com x.y@place.edu))
  end

  it 'can handle a complex user name validation regex' do
    # https://github.com/DavyJonesLocker/client_side_validations/issues/615
    regex = /\A[\p{L}0-9\-_\s]+\z/
    given_the_ruby_regexp(regex)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'äöü-23 x_X master',
                                with_results: ['äöü-23 x_X master'])
    expect_ruby_and_js_to_match(string: 'a:', with_results: [])
    expect_ruby_and_js_to_match(string: '. 9', with_results: [])
  end
end
