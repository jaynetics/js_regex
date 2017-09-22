
# JsRegex

[![Gem Version](https://badge.fury.io/rb/js_regex.svg)](http://badge.fury.io/rb/js_regex)
[![Build Status](https://travis-ci.org/janosch-x/js_regex.svg?branch=master)](https://travis-ci.org/janosch-x/js_regex)
[![Dependency Status](https://gemnasium.com/janosch-x/js_regex.svg)](https://gemnasium.com/janosch-x/js_regex)
[![Code Climate](https://codeclimate.com/github/janosch-x/js_regex/badges/gpa.svg)](https://codeclimate.com/github/janosch-x/js_regex)
[![Test Coverage](https://codeclimate.com/github/janosch-x/js_regex/badges/coverage.svg)](https://codeclimate.com/github/janosch-x/js_regex/coverage)

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
js_regex.source # => '[a-fA-F0-9]+'
js_regex.options # => 'g'
```

If you want to inject the result directly into JavaScript, use *#to_s* or String interpolation. E.g. in inline JavaScript in HAML or SLIM you can simply do:

```javascript
var regExp = #{js_regex};
```

If you want to convey it as a data attribute of a DOM element, use *#to_h*.

```ruby
js_regex.to_h # => {source: '[a-fA-F0-9]+', options: 'g'}
```

Use *#to_json* if you want to send it as JSON. In a Rails controller you can simply do:

```ruby
render json: js_regex
```

To turn the data attribute or parsed JSON object back into a regex in JavaScript, use the *new RegExp()* constructor:

```javascript
var regExp = new RegExp(jsonObj.source, jsonObj.options);
```

<a name='HW'></a>
### Heed the Warnings

You might have noticed the empty *warnings* array in the example above:

```ruby
js_regex = JsRegex.new(ruby_hex_regex)
js_regex.warnings # => []
```

If this array isn't empty, that means that your Ruby regex contained some [stuff that can't be carried over to JavaScript](#UF). You can still use the result, but this is not recommended. Most likely it won't match the same strings as your Ruby regex.

```ruby
# this Ruby regex will match c-x
advanced_ruby_regex = /[a-x&&c-z]/

# the resulting JavaScript regex will match a-z
js_regex = JsRegex.new(advanced_ruby_regex)

js_regex.warnings # => ["Dropped unsupported set intersection '&&' at index 4"]
js_regex.source # => '[a-xc-z]'
```

<a name='SF'></a>
### Supported Features

In addition to the conversions supported by the default approach, this gem will correctly handle the following features:

| Description                | Example           |
|----------------------------|-------------------|
| escaped meta chars         | \\\A              |
| Ruby's multiline mode [4]  | /.+/m             |
| Ruby's free-spacing mode   | / http (s?) /x    |
| atomic groups [5]          | a(?>bc\|b)c       |
| possessive quantifiers [5] | ++, *+, ?+, {4,}+ |
| hex types \h and \H        | \H\h{6}           |
| newline-ready anchor \Z    | last word\Z       |
| generic linebreak \R       | data.split(/\R/)  |
| meta and control escapes   | /\M-\C-X/         |
| literal whitespace         | [a-z ]            |
| nested sets                | [a-z[A-Z]]        |
| types in sets              | [a-z\h]           |
| properties in sets         | [a-z\p{sc}]       |
| posix types                | [[:alpha:]]       |
| posix negations            | [[:^alpha:]]      |
| unicode bmp scripts        | \p{Arabic}        |
| unicode blocks             | \p{InBasicLatin1} |
| unicode categories [6]     | \p{Number}        |
| unicode properties [6]     | \p{Dash}          |
| unicode ages [6]           | \p{Age=5.2}       |
| unicode abbreviations [6]  | \p{Mong}, \p{Sc}  |
| unicode negations [6]      | \p{^Number}       |
| codepoint lists            | \u{61 63 1F601}   |
| astral plane literals [7]  | &#x1f601;         |

[4] Keep in mind that [Ruby's multiline mode](http://ruby-doc.org/core-2.1.1/Regexp.html#class-Regexp-label-Options) is totally different from [JavaScript's multiline mode](http://javascript.info/regexp-multiline-mode).

[5] JavaScript doesn't support atomic groups or possessive quantifiers, but JsRegex emulates their behavior by substituting them with [backreferenced lookahead groups](http://instanceof.me/post/52245507631/regex-emulate-atomic-grouping-with-lookahead).

[6] Some properties from these groups will result in very large JavaScript regexes.

[7] Astral plane characters are converted to surrogate pairs, so they don't require ES6.

<a name='UF'></a>
### Unsupported Features

Currently, the following functionalities can't be carried over to JavaScript. If you try to convert a regex that uses these features, corresponding parts of the pattern will be dropped from the result. In most of these cases that will lead to a warning, but changes that are not considered risky happen without warning. E.g. comments are removed silently because that won't lead to any operational differences between the Ruby and JavaScript regexes.

| Description                    | Example               | Warning |
|--------------------------------|-----------------------|---------|
| lookbehind                     | (?&lt;=, (?&lt;!, \K  | yes     |
| conditionals                   | (?(a)b\|c)            | yes     |
| group-specific options         | (?i:, (?-i:           | yes     |
| capturing group names          | (?&lt;a&gt;, (?'a'    | no      |
| comment groups                 | (?#comment)           | no      |
| inline comments (in x-mode)    | /[a-z] # comment/x    | no      |
| multiplicative quantifiers     | /A{4}{6}/ =~ 'A' * 24 | no      |
| set intersections              | [a-z&amp;&amp;[^uo]]  | yes     |
| recursive set negation         | [^a[^b]]              | yes     |
| forward references             | (\2two\|(one))        | yes     |
| backreferences after atomics   | a(?>bc\|b)c(d)\1      | yes     |
| \k-backreferences              | (a)\k&lt;1&gt;        | yes     |
| subexpression calls            | (?'a'.)\g'a'/, \G     | yes     |
| absence operator               | (?~foo)               | yes     |
| bell and escape chars          | \a, \e                | yes     |
| extended grapheme type         | \X                    | yes     |
| wide hex escapes               | \x{1234}              | yes     |
| astral plane scripts           | \p{Deseret}           | yes     |
| astral plane ranges            | [&#x1f601;-&#x1f632;] | yes     |

In addition, the word boundaries `\b` and `\B` cause warnings since they are not unicode-ready in JavaScript. Unfortunately this [holds true even for the latest versions of JavaScript](http://www.ecma-international.org/ecma-262/6.0/#sec-runtime-semantics-iswordchar-abstract-operation).

Ruby:
```ruby
'Erkki-Sven Tüür'.split(/\b/) # => ["Erkki", "-", "Sven", " ", "Tüür"]
```

JavaScript:
```javascript
'Erkki-Sven Tüür'.split(/\b/) // => ["Erkki", "-", "Sven", " ", "T", "üü", "r"]
```

### Contributions

Feel free to send suggestions, point out issues, or submit pull requests.

### Credits

JsRegex uses ammar's powerful [regexp_parser](https://github.com/ammar/regexp_parser) gem.

### Outlook

A few more of the unsupported features listed above could be implemented with some work. For instance, set intersection might be achieved by expanding set members and ranges, intersecting them manually, and then recompressing them into new ranges. Something similar could be done for certain group-specific options, e.g. case-insensitive groups could be substituted by alternations with case-swapped members. However, no amount of effort will lead to a full solution. Some regex behavior is simply impossible to achieve in JavaScript, and [litte seems to be happening](https://mail.mozilla.org/pipermail/es-discuss/2013-September/033867.html) that could change that.
