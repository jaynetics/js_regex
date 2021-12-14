if ENV['CI'] && RUBY_VERSION.start_with?('2.7')
  require 'simplecov'
  SimpleCov.start

  ENV['CODECOV_TOKEN'] = '2276a5a2-709c-4a19-9096-824135a5c0b7'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require 'js_regex'

RSpec.configure do |config|
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
end

RSpec::Matchers.define(:become) do |expected|
  chain(:with_warning) { |warning = true| @expected_warning = warning }

  match do |rb_regex|
    js_regex = js_regex_for(rb_regex)
    expected_source = expected.is_a?(Regexp) ? expected.source : expected
    @msg = error_for_source(js_regex, expected_source) ||
           error_for_warnings(js_regex, @expected_warning)
    @msg.nil?
  end

  failure_message { @msg }
end

# some conversions are tested very often, this speeds up the specs a bit
def js_regex_for(rb_regex)
  $js_regex_cache ||= {}
  $js_regex_cache[rb_regex] ||= JsRegex.new(rb_regex, options: 'g')
end

def error_for_source(js_regex, expected)
  if js_regex.source != expected
    "expected #{expected}, got #{js_regex.source}"
  elsif !to_s_like_json(js_regex)
    '#to_s/#to_json sanity check failed'
  end
end

def error_for_warnings(js_regex, expected)
  warnings = js_regex.warnings
  if !expected
    "expected no warnings, got #{warnings}" if warnings.any?
  elsif warnings.count != 1
    "expected one warning, got #{warnings.count}"
  elsif expected.is_a?(String) && !(msg = warnings.first).include?(expected)
    "expected warning `#{msg}` to include `#{expected}`"
  end
end

RSpec::Matchers.define(:stay_the_same) do
  chain(:with_warning) { |warning = true| @expected_warning = warning }

  match do |rb_regex|
    js_regex = js_regex_for(rb_regex)
    @msg = error_for_source(js_regex, rb_regex.source) ||
           error_for_warnings(js_regex, @expected_warning)
    @msg.nil?
  end

  failure_message { @msg }
end

RSpec::Matchers.define(:generate_warning) do |expected = true|
  match do |rb_regex|
    js_regex = js_regex_for(rb_regex)
    @msg = error_for_warnings(js_regex, expected)
    @msg.nil?
  end

  failure_message { @msg }
end

RSpec::Matchers.define(:keep_matching) do |*test_strings, with_results: nil|
  match do |rb_regex|
    js_regex = js_regex_for(rb_regex)

    test_strings.each do |string|
      if with_results
        rb_matches = string.scan(rb_regex).flatten
        js_matches = matches_in_js(js_regex, string)
        rb_matches == with_results || @msg = "rb matched #{rb_matches}"
        js_matches == with_results || @msg = "js matched #{js_matches}"
      else
        # Due to JS' different splitting of group match data, some return values
        # are not completely identical between Ruby and JS matching calls.
        # In that case, don't specify expected results and just check that
        # a valid string does produce a match.
        rb_regex =~ string           || @msg = "rb did not match `#{string}`"
        test_in_js(js_regex, string) || @msg = "js did not match `#{string}`"
      end
    end

    @msg.nil?
  end

  failure_message { @msg }
end

RSpec::Matchers.define(:keep_not_matching) do |*test_strings|
  match do |rb_regex|
    js_regex = js_regex_for(rb_regex)

    test_strings.each do |string|
      rb_regex =~ string           && @msg = "rb did match `#{string}`"
      test_in_js(js_regex, string) && @msg = "js did match `#{string}`"
    end

    @msg.nil?
  end

  failure_message { @msg }
end

# match on [regexp_parser_token_class, regexp_parser_token_token]
RSpec::Matchers.define(:be_dropped_with_warning) do |substitute: ''|
  match do |(token_class, subtype)|
    exp = expression_double(type: token_class, token: subtype)
    allow(Regexp::Parser).to receive(:parse).and_return(exp)
    result = JsRegex.new(//)

    source = result.source
    source == substitute || @msg = "expected `#{substitute}`, got `#{source}`"
    result.warnings.count > 0 || @msg = 'did not warn'

    @msg.nil?
  end

  failure_message { @msg }
end

def expression_double(attributes)
  defaults = { case_insensitive?: false, map: [].map,
               quantifier: nil, to_s: 'X', ts: 0, i?: false }
  instance_double(Regexp::Expression::Root, defaults.merge(attributes))
end

require 'duktape'
JS_CONTEXT = Duktape::Context.new

def matches_in_js(js_regex, string)
  JS_CONTEXT.eval_string("'#{js_escape(string)}'.match(#{js_regex});").to_a
end

def test_in_js(js_regex, string)
  JS_CONTEXT.eval_string("#{js_regex}.test('#{js_escape(string)}');")
end

def to_s_like_json(js_regex)
  json_string = js_escape(js_regex.to_json)
  js = <<-JS
    "use strict";

    var jsonObj = JSON.parse('#{json_string}');
    var jsonRE = new RegExp(jsonObj.source, jsonObj.options);
    var stringRE = #{js_regex};
    jsonRE.source == stringRE.source && jsonRE.flags == stringRE.flags;
  JS
  JS_CONTEXT.eval_string(js)
end

def js_escape(string)
  string
    .gsub('\\') { '\\\\' } # this actually replaces one backslash with two
    .gsub("'") { "\\'" } # http://stackoverflow.com/revisions/12701027/2
    .gsub("\n", '\\n')
    .gsub("\r", '\\r')
end
