# frozen_string_literal: true

# whitelist some mutations
defined?(Mutant) && Mutant::Mutator::Node::Send.prepend(Module.new do
  def emit_selector_replacement
    super unless %i[first =~].include?(selector)
  end
end)

RSpec.configure do |config|
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
end

require 'js_regex'

require 'v8' # gem 'therubyracer'
JS_CONTEXT = V8::Context.new

def given_the_ruby_regexp(ruby_regex)
  @ruby_regex = ruby_regex
  @js_regex = JsRegex.new(ruby_regex, options: 'g')
end

def expect_js_regex_to_be(expected)
  expect(js_regex_source).to eq(expected.source)
  expect_to_s_to_eq_json
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

def js_regex_source
  @js_regex.source
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
    expect(matches_in_js_on(data)).not_to be_empty
  else
    expect(matches_in_ruby_on(data)).to eq(expected)
    expect(matches_in_js_on(data)).to eq(expected)
  end
end

def expect_ruby_and_js_not_to_match(args = { string: '' })
  expect_ruby_and_js_to_match(string: args[:string], with_results: [])
end

def matches_in_ruby_on(string)
  string.scan(@ruby_regex).flatten
end

def matches_in_js_on(string)
  test_string = escape_for_js_string_evaluation(string)
  js = <<-JS
    var matches = '#{test_string}'.match(#{@js_regex});
    if (matches === null) matches = [];
    matches;
  JS
  JS_CONTEXT.eval(js).to_a
end

def expect_to_s_to_eq_json
  json_string = escape_for_js_string_evaluation(@js_regex.to_json)
  js = <<-JS
    var jsonObj = JSON.parse('#{json_string}');
    var jsonRE = new RegExp(jsonObj.source, jsonObj.options);
    var stringRE = #{@js_regex};
    jsonRE.source == stringRE.source && jsonRE.flags == stringRE.flags;
  JS
  expect(JS_CONTEXT.eval(js)).to eq true
end

def escape_for_js_string_evaluation(test_string)
  test_string
    .gsub('\\') { '\\\\' } # this actually replaces one backslash with two
    .gsub("'") { "\\'" } # http://stackoverflow.com/revisions/12701027/2
    .gsub("\n", '\\n')
    .gsub("\r", '\\r')
end

def expect_to_drop_token_with_warning(token_class, subtype)
  given_the_token(token_class, subtype)
  expect_js_regex_to_be(//)
  expect_warning
end

def given_the_token(token_class, subtype)
  exp = expression_double(type: token_class, token: subtype)
  allow(Regexp::Parser).to receive(:parse).and_return(exp)
  @js_regex = JsRegex.new(//)
end

def expression_double(attributes)
  defaults = { case_insensitive?: false, map: [].map,
               quantifier: nil, to_s: 'X', ts: 0, i?: false }
  instance_double(Regexp::Expression::Root, defaults.merge(attributes))
end
