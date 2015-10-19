# encoding: utf-8

require 'spec_helper'

describe JsRegex do
  it 'can handle ambidextrous apostrophes' do
    given_the_ruby_regexp(/'/)
    expect_js_regex_to_be(/'/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "'", with_results: %w('))
  end

  it 'can handle ambidextrous quotation marks' do
    given_the_ruby_regexp(/"/)
    expect_js_regex_to_be(/"/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '"', with_results: %w("))
  end

  it 'can handle a complex email validation regex' do
    regex = /[a-z0-9!$#%&'*+=?^_\`\{|\}~-]+
             (?:\.[a-z0-9!$#%&'*+=?^_\`\{|}~-]+)*@
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

  it 'can handle the email validation regex of the devise gem' do
    # regexp from: https://github.com/plataformatec/devise/blob/
    # 7df57d5081f9884849ca15e4fde179ef164a575f/lib/devise.rb

    given_the_ruby_regexp(/\A[^@\s]+@(?:[^@\s]+\.)+[^@\W]+\z/)
    expect_js_regex_to_be(/^[^@\s]+@(?:[^@\s]+\.)+[^@\W]+$/)
    expect_no_warnings

    # examples from: https://github.com/plataformatec/devise/blob/
    # 7df57d5081f9884849ca15e4fde179ef164a575f/test/devise_test.rb

    valid_emails = ['test@example.com', 'jo@jo.co', 'f4$_m@you.com',
                    'testing.example@example.com.ua']
    non_valid_emails = ['rex', 'test@go,com', 'test user@example.com',
                        'test_user@example server.com',
                        'test_user@example.com.']

    valid_emails.each do |address|
      expect_ruby_and_js_to_match(string: address, with_results: [address])
    end
    non_valid_emails.each do |address|
      expect_ruby_and_js_to_match(string: address, with_results: [])
    end
  end
end
