# frozen_string_literal: true

require 'spec_helper'
require 'uri'

describe JsRegex do
  it 'can handle a complex email validation regex' do
    given_the_ruby_regexp(
      /[a-z0-9!$#%&'*+=?^_\`\{|\}~-]+
      (?:\.[a-z0-9!$#%&'*+=?^_\`\{|}~-]+)*@
      (?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+
      (?:[A-Z]{2}|com|org|net|edu|gov|mil|
      biz|info|mobi|name|aero|asia|jobs|museum)\b/xi
    )
    expect_warning("boundary '\\b' at index 210 is not unicode-aware")
    expect_ruby_and_js_to_match(string: 'a@b me@s-w.com x.y@place.edu #ö+.',
                                with_results: %w[me@s-w.com x.y@place.edu])
  end

  it 'can handle a complex user name validation regex' do
    # https://github.com/DavyJonesLocker/client_side_validations/issues/615
    given_the_ruby_regexp(/\A[\p{L}0-9\-_\s]+\z/)
    expect_warning('astral plane')
    expect_ruby_and_js_to_match(string: 'äöü-23 x_X master',
                                with_results: ['äöü-23 x_X master'])
    expect_ruby_and_js_not_to_match(string: 'a:')
    expect_ruby_and_js_not_to_match(string: '. 9')
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
    invalid_emails = ['rex', 'test@go,com', 'test user@example.com',
                      'test_user@example server.com',
                      'test_user@example.com.']

    valid_emails.each do |address|
      expect_ruby_and_js_to_match(string: address, with_results: [address])
    end
    invalid_emails.each do |address|
      expect_ruby_and_js_not_to_match(string: address)
    end
  end

  it 'can handle Ruby\'s URI regexp' do
    given_the_ruby_regexp(URI::DEFAULT_PARSER.make_regexp)
    expect_no_warnings

    valid_uris = %w[http://ab.de ftp://142.42.1.1:8080/ http://مثال.إختبار]
    invalid_uris = %w[http htt?:// foo.com]

    valid_uris.each do |uri|
      expect_ruby_and_js_to_match(string: uri)
    end
    invalid_uris.each do |uri|
      expect_ruby_and_js_not_to_match(string: uri)
    end
  end

  it 'can handle ambidextrous apostrophes' do
    given_the_ruby_regexp(/'/)
    expect_js_regex_to_be(/'/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "'", with_results: %w['])
  end

  it 'can handle ambidextrous quotation marks' do
    given_the_ruby_regexp(/"/)
    expect_js_regex_to_be(/"/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '"', with_results: %w["])
  end
end
