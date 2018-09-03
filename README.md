
# JsRegex

[![Gem Version](https://badge.fury.io/rb/js_regex.svg)](http://badge.fury.io/rb/js_regex)
[![Build Status](https://travis-ci.org/janosch-x/js_regex.svg?branch=master)](https://travis-ci.org/janosch-x/js_regex)
[![Code Climate](https://codeclimate.com/github/janosch-x/js_regex/badges/gpa.svg)](https://codeclimate.com/github/janosch-x/js_regex)

This is a Ruby gem that translates Ruby's regular expressions to the JavaScript flavor.

It has two advantages when compared to the most widespread approach
[[1]](https://dockyard.com/blog/ruby/2011/11/18/convert-ruby-regexp-to-javascript-regex)
[[2]](https://github.com/rails/rails/blob/b67043393b5ed6079989513299fe303ec3bc133b/actionpack/lib/action_dispatch/routing/inspector.rb#L42)
[[3]](https://github.com/DavyJonesLocker/client_side_validations/blob/7f0a570f3d88628aeeb6cd61864a8af61ebbf887/lib/client_side_validations/core_ext/regexp.rb#L3)
:

1. It [can handle far more](#SF) of Ruby's regex capabilities.
2. If any incompatibilities remain, it returns [helpful warnings](#HW) to indicate them.

This means you'll have better chances of translating your regexes, and if there is still a problem, at least you'll know.

### Installation

Add it to your gemfile or run

    gem install js_regex

### Usage

In Ruby:

```ruby
require 'js_regex'

ruby_hex_regex = /\h+/

js_regex = JsRegex.new(ruby_hex_regex)

js_regex.warnings # => []
js_regex.source # => '[0-9A-Fa-f]+'
js_regex.options # => 'g'
```

If you want to inject the result directly into JavaScript, use `#to_s` or String interpolation. E.g. in inline JavaScript in HAML or SLIM you can simply do:

```javascript
var regExp = #{js_regex};
```

If you want to convey it as a data attribute of a DOM element, use `#to_h`.

```ruby
js_regex.to_h # => {source: '[0-9A-Fa-f]+', options: 'g'}
```

Use `#to_json` if you want to send it as JSON. In a Rails controller you can simply do:

```ruby
render json: js_regex
```

To turn the data attribute or parsed JSON object back into a regex in JavaScript, use the `new RegExp()` constructor:

```javascript
var regExp = new RegExp(jsonObj.source, jsonObj.options);
```

<a name='HW'></a>
### Heed the Warnings

You might have noticed the empty `warnings` array in the example above:

```ruby
js_regex = JsRegex.new(ruby_hex_regex)
js_regex.warnings # => []
```

If this array isn't empty, that means that your Ruby regex contained some [stuff that can't be carried over to JavaScript](#UF). You can still use the result, but this is not recommended. Most likely it won't match the same strings as your Ruby regex.

```ruby
# this Ruby regex will match 'br', 'bur', etc.
advanced_ruby_regex = /b(?~a)r]/

# the resulting JavaScript regex will match 'br'
js_regex = JsRegex.new(advanced_ruby_regex)

js_regex.warnings # => ["Dropped unsupported absence group '(?~a)' at index 1"]
js_regex.source # => 'br'
```

Many warnings are related to JavaScript regexes not matching stuff in the astral plane. Ignoring these might be fine depending on your use case.

<a name='SF'></a>
### Supported Features

In addition to the conversions supported by the default approach, this gem will correctly handle the following features:

| Description                   | Example               |
|-------------------------------|-----------------------|
| escaped meta chars            | \\\A                  |
| Ruby's multiline mode [4]     | /.+/m                 |
| Ruby's free-spacing mode      | / http (s?) /x        |
| atomic groups [5]             | a(?>bc\|b)c           |
| option groups/switches        | (?i-m:..), (?x)..     |
| possessive quantifiers [5]    | ++, *+, ?+, {4,}+     |
| hex types \h and \H           | \H\h{6}               |
| bell and escape shortcuts     | \a, \e                |
| newline-ready anchor \Z       | last word\Z           |
| generic linebreak \R          | data.split(/\R/)      |
| meta and control escapes      | /\M-\C-X/             |
| numeric backreferences        | \1, \k&lt;1&gt;       |
| relative backreferences       | \k&lt;-1&gt;          |
| named backreferences          | \k&lt;foo&gt;         |
| numeric subexpression calls   | \1, \g&lt;1&gt;       |
| relative subexpression calls  | \g&lt;-1&gt;          |
| named subexpression calls     | \g&lt;foo&gt;         |
| literal whitespace            | [a-z ]                |
| nested sets                   | [a-z[A-Z]]            |
| types in sets                 | [a-z\h]               |
| properties in sets            | [a-z\p{sc}]           |
| set intersections             | [\w&amp;&amp;[^a]]    |
| recursive set negation        | [^a[^b]]              |
| posix types                   | [[:alpha:]]           |
| posix negations               | [[:^alpha:]]          |
| codepoint lists               | \u{61 63 1F601}       |
| unicode properties [6]        | \p{Arabic}, \p{Dash}  |
| unicode abbreviations [6]     | \p{Mong}, \p{Sc}      |
| unicode negations [6]         | \p{^Number}           |
| astral plane properties [6][7]| \p{emoji}             |
| astral plane literals [7]     | &#x1f601;             |
| astral plane ranges [7]       | [&#x1f601;-&#x1f632;] |


[4] Keep in mind that [Ruby's multiline mode](http://ruby-doc.org/core-2.1.1/Regexp.html#class-Regexp-label-Options) is more of a "dot-all mode" and totally different from [JavaScript's multiline mode](http://javascript.info/regexp-multiline-mode).

[5] JavaScript doesn't support atomic groups or possessive quantifiers, but JsRegex emulates their behavior by substituting them with [backreferenced lookahead groups](http://instanceof.me/post/52245507631/regex-emulate-atomic-grouping-with-lookahead).

[6] Some properties from these groups will result in large JavaScript regexes.

[7] Astral plane characters are converted to surrogate pairs, so they don't require ES6. Large astral plane ranges or properties are dropped, though, to limit the size of the resulting regex.

<a name='UF'></a>
### Unsupported Features

Currently, the following functionalities can't be carried over to JavaScript. If you try to convert a regex that uses these features, corresponding parts of the pattern will be dropped from the result. In most of these cases that will lead to a warning, but changes that are not considered risky happen without warning. E.g. comments are removed silently because that won't lead to any operational differences between the Ruby and JavaScript regexes.

| Description                    | Example               | Warning |
|--------------------------------|-----------------------|---------|
| lookbehind                     | (?&lt;=, (?&lt;!, \K  | yes     |
| conditionals                   | (?(a)b\|c)            | yes     |
| local encoding options         | (?u:\w)               | yes     |
| capturing group names          | (?&lt;a&gt;, (?'a'    | no      |
| comment groups                 | (?#comment)           | no      |
| inline comments (in x-mode)    | /[a-z] # comment/x    | no      |
| multiplicative quantifiers     | /A{4}{6}/ =~ 'A' * 24 | no      |
| forward references             | (\2two\|(one))        | yes     |
| whole pattern recursion        | \g<0>                 | yes     |
| absence groups                 | (?~foo)               | yes     |
| previous match anchor          | \G                    | yes     |
| extended grapheme type         | \X                    | yes     |
| large astral plane ranges      | [a-\u{10FFFF}]        | yes     |

In addition, the word boundaries `\b` and `\B` cause warnings since they are not unicode-ready in JavaScript. Unfortunately this [holds true even for the latest versions of JavaScript](http://www.ecma-international.org/ecma-262/6.0/#sec-runtime-semantics-iswordchar-abstract-operation).

Ruby:
```ruby
'Erkki-Sven Tüür'.split(/\b/) # => ["Erkki", "-", "Sven", " ", "Tüür"]
```

JavaScript:
```javascript
'Erkki-Sven Tüür'.split(/\b/)  // => ["Erkki", "-", "Sven", " ", "T", "üü", "r"]
'Erkki-Sven Tüür'.split(/\b/u) // => ["Erkki", "-", "Sven", " ", "T", "üü", "r"]
```

### Contributions

Feel free to send suggestions, point out issues, or submit pull requests.

### Outlook

Possible future improvements might include an "ES6 mode" using [the `u` flag](https://javascript.info/regexp-unicode), which would allow for much more concise representations of astral plane properties and sets. As far as supported conversions are concerned, this gem is almost feature-complete. Most of the unsupported features listed above are impossible to replicate in JavaScript, and [litte seems to be happening](https://mail.mozilla.org/pipermail/es-discuss/2013-September/033867.html) that could change that.
