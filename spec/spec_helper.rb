
if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.2.2')
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
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
  expect_warnings(0)
end

def expect_warning
  expect_warnings(1)
end

def expect_warnings(count)
  expect(@js_regex.warnings.count).to eq(count)
end

def expect_ruby_and_js_to_match(args = { string: '', with_results: [] })
  # this is a kind of quick, inline integration test, checking whether the
  # produced js really has the same matching results as the Ruby source.
  string = args[:string]
  results = args[:with_results]

  expect(matches_in_ruby_on(string)).to eq(results)
  expect(matches_in_javascript_using_to_s_result_on(string)).to eq(results)
  expect(matches_in_javascript_using_to_json_result_on(string)).to eq(results)
end

def expect_ruby_and_js_to_match_string(string)
  # Due to JS' different splitting of group match data, some return values
  # are not completely identical between Ruby and JS matching calls.
  # In that case, just check that a valid string does produce a match.
  expect(matches_in_ruby_on(string)).not_to be_empty
  expect(matches_in_javascript_using_to_s_result_on(string)).not_to be_empty
  expect(matches_in_javascript_using_to_json_result_on(string)).not_to be_empty
end

def matches_in_ruby_on(string)
  string.scan(@ruby_regex).flatten
end

def matches_in_javascript_using_to_s_result_on(string)
  test_string = escape_for_js_string_evaluation(string)
  js = <<-EOF
    var matches = '#{test_string}'.match(#{@js_regex});
    if (matches === null) matches = [];
    matches;
  EOF
  JS_CONTEXT.eval(js).to_a
end

def matches_in_javascript_using_to_json_result_on(string)
  json_string = escape_for_js_string_evaluation(@js_regex.to_json)
  test_string = escape_for_js_string_evaluation(string)
  js = <<-EOF
    var jsonObj = JSON.parse('#{json_string}');
    var regExp = new RegExp(jsonObj.source, jsonObj.options);
    var matches = '#{test_string}'.match(regExp);
    if (matches === null) matches = [];
    matches;
  EOF
  JS_CONTEXT.eval(js).to_a
end

def escape_for_js_string_evaluation(test_string)
  test_string
    .gsub('\\') { '\\\\' } # this actually replaces one backslash with two
    .gsub("'") { "\\'" } # http://stackoverflow.com/revisions/12701027/2
    .gsub("\n", '\\n')
    .gsub("\r", '\\r')
end

def ruby_version_at_least?(version_string)
  Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new(version_string)
end
