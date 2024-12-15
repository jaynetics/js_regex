require 'spec_helper'
require 'uri'

describe LangRegex do
  let(:email_validation_regex) do
    /
      [a-z0-9!$#%&'*+=?^_\`\{|\}~-]+
      (?:\.[a-z0-9!$#%&'*+=?^_\`\{|}~-]+)*@
      (?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+
      (?:[A-Z]{2}|com|org|net|edu|gov|mil|
      biz|info|mobi|name|aero|asia|jobs|museum)\b
    /xi
  end

  it 'can handle a complex email validation regex', targets: [ES2009, ES2015] do
    expect(email_validation_regex)
      .to generate_warning("'\\b' at index 217 only works at ASCII word boundaries")
      .and keep_matching('a@b me@s-w.com x.y@place.edu #ö+.',
                         with_results: %w[me@s-w.com x.y@place.edu])
  end

  it 'can handle the email regex without warning on ES2018+', targets: [ES2018] do
    expect(email_validation_regex)
      .to keep_matching('a@b me@s-w.com x.y@place.edu #ö+.',
                        with_results: %w[me@s-w.com x.y@place.edu])
  end

  it 'can handle a complex user name validation regex' do
    # https://github.com/DavyJonesLocker/client_side_validations/issues/615
    expect(/\A[\p{L}0-9\-_\s]+\z/)
      .to  keep_matching('äöü-23 x_X master', with_results: ['äöü-23 x_X master'])
      .and keep_not_matching('a:', '. 9')
  end

  it 'can handle the email validation regex of the devise gem' do
    # regexp from: https://github.com/plataformatec/devise/blob/
    # 7df57d5081f9884849ca15e4fde179ef164a575f/lib/devise.rb
    # examples from: https://github.com/plataformatec/devise/blob/
    # 7df57d5081f9884849ca15e4fde179ef164a575f/test/devise_test.rb
    valid_emails = ['test@example.com', 'jo@jo.co', 'f4$_m@you.com',
                    'testing.example@example.com.ua']
    invalid_emails = ['rex', 'test@go,com', 'test user@example.com',
                      'test_user@example server.com',
                      'test_user@example.com.']

    expect(/\A[^@\s]+@(?:[^@\s]+\.)+[^@\W]+\z/).to\
    become(/^[^@\s]+@(?:[^@\s]+\.)+[^@\W]+$/)
      .and keep_matching(*valid_emails)
      .and keep_not_matching(*invalid_emails)
  end

  it 'can handle Ruby\'s URI regexp' do
    expect(URI::DEFAULT_PARSER.make_regexp)
      .to  keep_matching('http://ab.de', 'ftp://142.42.1.1:8080/', 'http://مثال.إختبار]')
      .and keep_not_matching('http', 'htt?://', 'foo.com')
  end

  it 'can handle ambidextrous apostrophes' do
    expect(/'/).to stay_the_same.and keep_matching("'")
  end

  it 'can handle ambidextrous quotation marks' do
    expect(/"/).to stay_the_same.and keep_matching('"')
  end
end
