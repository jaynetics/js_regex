# frozen_string_literal: true

describe 'keep_capturing' do
  it 'checks the first matched text and chains with other matchers' do
    expect(/a+/i).to stay_the_same.and keep_capturing('bAAaAba' => 'AAaA')
  end

  it 'checks capture groups when an array is expected' do
    expect(/(a)?b/).to keep_capturing('ab' => ['ab', 'a'], 'b' => ['b', nil])
  end

  it 'distinguishes empty matches, empty captures, and missing matches' do
    expect(/a*/).to keep_capturing('x' => '')
    expect(/()/).to keep_capturing('x' => ['', ''])
    expect(/a/).to keep_capturing('x' => nil)
  end

  it 'passes quotes, backslashes, and line breaks safely to JavaScript' do
    input = "'\"\\\n"
    expect(/[\s\S]+/).to keep_capturing(input => input)
  end

  it 'rejects an incorrect Ruby result even when JavaScript matches the expectation' do
    matcher = keep_capturing('a' => nil)
    allow(matcher).to receive(:conversions).and_return(ES2009 => JsRegex.new(/b/))

    expect(matcher.matches?(/a/)).to eq(false)
    expect(matcher.failure_message).to include('expected Ruby to capture nil from "a", got "a"')
  end

  it 'rejects incorrect JavaScript groups even when the matched text is correct' do
    matcher = keep_capturing('a' => ['a', 'a'])
    allow(matcher).to receive(:conversions).and_return(ES2009 => JsRegex.new(/a/))

    expect(matcher.matches?(/(a)/)).to eq(false)
    expect(matcher.failure_message).to include('expected JS to capture ["a", "a"] from "a", got ["a"]')
  end

  it 'checks later targets and identifies the input and target on failure' do
    matcher = keep_capturing('a' => 'a')
    allow(matcher).to receive(:conversions).and_return(
      ES2009 => JsRegex.new(/a/), ES2015 => JsRegex.new(/b/)
    )

    expect(matcher.matches?(/a/)).to eq(false)
    expect(matcher.failure_message).to include('from "a", got nil', 'for ES2015')
  end
end
