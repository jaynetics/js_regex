# encoding: utf-8
# frozen_string_literal: true

require_relative File.join('..', 'build')

if JsRegex::PERFORM_FULL_BUILD
  require 'simplecov'
  SimpleCov.start
end

RSpec.configure do |config|
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
end

require 'js_regex'

require 'v8' # gem 'therubyracer'
JS_CONTEXT = V8::Context.new

def given_the_ruby_regexp(ruby_regex)
  @ruby_regex = ruby_regex
  @js_regex = JsRegex.new(ruby_regex)
end

def expect_js_regex_to_be(expected)
  expect(@js_regex.source).to eq(expected.source)
end

def expect_no_warnings
  expect(@js_regex.warnings).to be_empty
end

def expect_warning(specific_text = nil)
  expect_warnings(1)
  expect(@js_regex.warnings.first).to include(specific_text) if specific_text
end

def expect_warnings(count)
  expect(@js_regex.warnings.count).to eq(count)
end

def expect_ruby_and_js_to_match(args = { string: '', with_results: [] })
  # this is a kind of quick, inline integration test, checking whether the
  # produced js really has the same matching results as the Ruby source.
  data = args[:string]
  expected = args[:with_results]

  if expected.nil?
    # Due to JS' different splitting of group match data, some return values
    # are not completely identical between Ruby and JS matching calls.
    # In that case, don't specify expected results and just check that
    # a valid string does produce a match.
    expect(matches_in_ruby_on(data)).not_to be_empty
    expect(matches_in_javascript_using_to_s_result_on(data)).not_to be_empty
    expect(matches_in_javascript_using_to_json_result_on(data)).not_to be_empty
  else
    expect(matches_in_ruby_on(data)).to eq(expected)
    expect(matches_in_javascript_using_to_s_result_on(data)).to eq(expected)
    expect(matches_in_javascript_using_to_json_result_on(data)).to eq(expected)
  end
end

def expect_ruby_and_js_not_to_match(args = { string: '' })
  expect_ruby_and_js_to_match(string: args[:string], with_results: [])
end

def matches_in_ruby_on(string)
  string.scan(@ruby_regex).flatten
end

def matches_in_javascript_using_to_s_result_on(string)
  test_string = escape_for_js_string_evaluation(string)
  js = <<-JS
    var matches = '#{test_string}'.match(#{@js_regex});
    if (matches === null) matches = [];
    matches;
  JS
  JS_CONTEXT.eval(js).to_a
end

def matches_in_javascript_using_to_json_result_on(string)
  json_string = escape_for_js_string_evaluation(@js_regex.to_json)
  test_string = escape_for_js_string_evaluation(string)
  js = <<-JS
    var jsonObj = JSON.parse('#{json_string}');
    var regExp = new RegExp(jsonObj.source, jsonObj.options);
    var matches = '#{test_string}'.match(regExp);
    if (matches === null) matches = [];
    matches;
  JS
  JS_CONTEXT.eval(js).to_a
end

def escape_for_js_string_evaluation(test_string)
  test_string
    .gsub('\\') { '\\\\' } # this actually replaces one backslash with two
    .gsub("'") { "\\'" } # http://stackoverflow.com/revisions/12701027/2
    .gsub("\n", '\\n')
    .gsub("\r", '\\r')
end

def expect_to_drop_token_with_warning(token_class, subtype)
  exp = expression_double({ type: token_class, token: subtype })
  converter = JsRegex::Converter.for(exp)
  expect(converter).to be_a(described_class)

  source, warnings = converter.convert(exp, JsRegex::Converter::Context.new(//))
  expect(source).to be_empty
  expect(warnings.size).to eq(1)
end

def expression_double(attributes)
  defaults = { expressions: [], quantifier: nil, to_s: 'X', ts: 0 }
  instance_double(Regexp::Expression::Root, defaults.merge(attributes))
end

def ruby_version_at_least?(version_string)
  Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new(version_string)
end
