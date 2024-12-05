# JsRegex

[![Gem Version](https://badge.fury.io/rb/js_regex.svg)](http://badge.fury.io/rb/js_regex)
[![Build Status](https://github.com/jaynetics/js_regex/workflows/tests/badge.svg)](https://github.com/jaynetics/js_regex/actions)
[![Build Status](https://github.com/jaynetics/js_regex/workflows/gouteur/badge.svg)](https://github.com/jaynetics/js_regex/actions)
[![Coverage](https://codecov.io/gh/jaynetics/js_regex/branch/main/graph/badge.svg?token=jYoA3bnAKY)](https://codecov.io/gh/jaynetics/js_regex)

This is a Ruby gem that translates Ruby's regular expressions to various JavaScript flavors.

It can handle [almost all of Ruby's regex features](#SF), unlike a [search-and-replace approach](https://github.com/rails/rails/blob/b67043393b5ed6079989513299fe303ec3bc133b/actionpack/lib/action_dispatch/routing/inspector.rb#L42). If any incompatibilities remain, it returns [helpful warnings](#HW) to indicate them.

## Installation

Add it to your gemfile or run

    gem install js_regex

## Usage

### Basic usage

In Ruby:

```ruby
require 'lang_regex'

ruby_hex_regex = /0x\h+/i

# To JS
js_regex = LangRegex::JsRegex.new(ruby_hex_regex)
# To PHP
php_regex = LangRegex::Php.new(ruby_hex_regex)

js_regex.warnings # => []
js_regex.source # => '0x[0-9A-F]+'
js_regex.options # => 'i'
```

To inject the result directly into JavaScript, use `#to_s` or String interpolation. E.g. in inline JavaScript in HAML or SLIM you can simply do:

```javascript
var regExp = #{js_regex};
```

Use `#to_json` if you want to send it as JSON or `#to_h` to include it as a data attribute of a DOM element.

```ruby
render json: js_regex

js_regex.to_h # => { source: '[0-9A-F]+', options: 'i' }
```

To turn the data attribute or parsed JSON back into a RegExp in JavaScript, use the `new RegExp()` constructor:

```javascript
var regExp = new RegExp(jsonObj.source, jsonObj.options);
```

<a name='HW'></a>
### Heed the Warnings

You might have noticed the empty `warnings` array in the example above:

```ruby
js_regex = LangRegex::JsRegex.new(ruby_hex_regex)
js_regex.warnings # => []
```

If this array isn't empty, that means that your Ruby regex contained some stuff that can't be carried over to JavaScript. You can still use the result, but this is not recommended. Most likely it won't match the same strings as your Ruby regex.

```ruby
advanced_ruby_regex = /(?<!fizz)buzz/

js_regex = LangRegex::JsRegex.new(advanced_ruby_regex)
js_regex.warnings # => ["Dropped unsupported negative lookbehind '(?<!fizz)' at index 0 (requires at least `target: 'ES2018'`)"]
js_regex.source # => 'buzz'
```

There is also a strict initializer, `LangRegex::new!`, which raises a `LangRegex::Error` if there are incompatibilites. This is particularly useful if you use JsRegex to convert regex-like strings, e.g. strings entered by users, as a `LangRegex::Error` might also occur if the given regex is invalid:

```ruby
begin
  user_input = '('
  LangRegex::JsRegex.new(user_input)
rescue LangRegex::Error => e
  e.message # => "Premature end of pattern (missing group closing parenthesis)"
end
```

### Modifying RegExp options/flags

An `options:` argument lets you append options (a.k.a. "flags") to the output:

```ruby
LangRegex::JsRegex.new(/x/i, options: 'g').to_h
# => { source: 'x', options: 'gi' }
```

Set the [g flag](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/global) like this if you want to use the regex to find or replace multiple matches per string.

### Converting for modern JavaScript

A `target:` argument can be given to target more recent versions of JS and unlock extra features or nicer output. `'ES2009'` is the default target. `'ES2015'` and `'ES2018'` are also available.

```ruby
# ES2015 and greater use the u-flag to avoid lengthy escape sequences
LangRegex::JsRegex.new(/😋/, target: 'ES2009').to_s # => "/(?:\\uD83D\\uDE0B)/"
LangRegex::JsRegex.new(/😋/, target: 'ES2015').to_s # => "/😋/u"
LangRegex::JsRegex.new(/😋/, target: 'ES2018').to_s # => "/😋/u"

# ES2018 adds support for lookbehinds, properties etc.
LangRegex::JsRegex.new(/foo\K\p{ascii}/, target: 'ES2015').to_s # => "/foo[\x00-\x7f]/"
LangRegex::JsRegex.new(/foo\K\p{ascii}/, target: 'ES2018').to_s # => "/(?<=foo)\p{ASCII}/"
```

<a name='SF'></a>
## Supported Features

These are the supported features by target.

Unsupported features are at the bottom of this list.

When converting a Regexp that contains unsupported features, corresponding parts of the pattern are dropped from the result and warnings are emitted.


| Description                 | Example              | ES2009 | ES2015 | ES2018 |
|-----------------------------|----------------------|--------|--------|--------|
| escaped meta chars          | \\\A                 | ✓      | ✓      | ✓      |
| dot matching astral chars   | /./ =~ '😋'          | ✓      | ✓      | ✓      |
| Ruby's multiline mode [1]   | /.+/m                | ✓      | ✓      | ✓      |
| Ruby's free-spacing mode    | / http (s?) /x       | ✓      | ✓      | ✓      |
| possessive quantifiers [2]  | ++, *+, ?+           | ✓      | ✓      | ✓      |
| atomic groups [2]           | a(?>bc\|b)c          | ✓      | ✓      | ✓      |
| conditionals [2]            | (?('a')b\|c)         | ✓      | ✓      | ✓      |
| option groups/switches      | (?i-m:..), (?x)..    | ✓      | ✓      | ✓      |
| local encoding options      | (?u:\w)              | ✓      | ✓      | ✓      |
| absence groups              | /\\\*(?~\\\*/)\\\*/  | ✓      | ✓      | ✓      |
| chained quantifiers         | /A{2}{4}/ =~ 'A' * 8 | ✓      | ✓      | ✓      |
| hex types \h and \H         | \H\h{6}              | ✓      | ✓      | ✓      |
| bell and escape shortcuts   | \a, \e               | ✓      | ✓      | ✓      |
| all literals, including \n  | eval("/\n/")         | ✓      | ✓      | ✓      |
| newline-ready anchor \Z     | last word\Z          | ✓      | ✓      | ✓      |
| generic linebreak \R        | data.split(/\R/)     | ✓      | ✓      | ✓      |
| meta and control escapes    | /\M-\C-X/            | ✓      | ✓      | ✓      |
| numeric backreferences      | \1, \k&lt;1&gt;      | ✓      | ✓      | ✓      |
| relative backreferences     | \k&lt;-1&gt;         | ✓      | ✓      | ✓      |
| named backreferences        | \k&lt;foo&gt;        | ✓      | ✓      | ✓      |
| numeric subexp calls        | \g&lt;1&gt;          | ✓      | ✓      | ✓      |
| relative subexp calls       | \g&lt;-1&gt;         | ✓      | ✓      | ✓      |
| named subexp calls          | \g&lt;foo&gt;        | ✓      | ✓      | ✓      |
| recursive subexp calls [3]  | \g<0>                | ✓      | ✓      | ✓      |
| nested sets                 | [a-z[A-Z]]           | ✓      | ✓      | ✓      |
| types in sets               | [a-z\h]              | ✓      | ✓      | ✓      |
| properties in sets          | [a-z\p{sc}]          | ✓      | ✓      | ✓      |
| set intersections           | [\w&amp;&amp;[^a]]   | ✓      | ✓      | ✓      |
| recursive set negation      | [^a[^b]]             | ✓      | ✓      | ✓      |
| posix types                 | [[:alpha:]]          | ✓      | ✓      | ✓      |
| posix negations             | [[:^alpha:]]         | ✓      | ✓      | ✓      |
| codepoint lists             | \u{61 63 1F601}      | ✓      | ✓      | ✓      |
| unicode properties          | \p{Dash}, \p{Thai}   | ✓      | ✓      | ✓      |
| unicode abbreviations       | \p{Mong}, \p{Sc}     | ✓      | ✓      | ✓      |
| unicode negations           | \p{^L}, \P{L}        | ✓      | ✓      | ✓      |
| astral plane properties [2] | \p{emoji}            | ✓      | ✓      | ✓      |
| astral plane literals [2]   | 😁                   | ✓      | ✓      | ✓      |
| astral plane ranges [2]     | [😁-😲]              | ✓      | ✓      | ✓      |
| capturing group names [4]   | (?&lt;a&gt;, (?'a'   | X      | X      | ✓      |
| extended grapheme type      | \X                   | X      | X      | ✓      |
| lookbehinds                 | (?<=a), (?<!a)       | X      | X      | ✓      |
| keep marks                  | \K                   | X      | X      | ✓      |
| sane word boundaries [5]    | \b, \B               | X      | X      | ✓      |
| nested keep mark            | /a(b\Kc)d/           | X      | X      | X      |
| backref by recursion level  | \k<1+1>              | X      | X      | X      |
| previous match anchor       | \G                   | X      | X      | X      |
| variable length absence     | (?~(a+\|bar))        | X      | X      | X      |
| comment groups [4]          | (?#comment)          | X      | X      | X      |
| inline comments [4]         | /[a-z] # comment/x   | X      | X      | X      |

[1] Keep in mind that [Ruby's multiline mode](http://ruby-doc.org/core-2.1.1/Regexp.html#class-Regexp-label-Options) is more of a "dot-all mode" and totally different from [JavaScript's multiline mode](http://javascript.info/regexp-multiline-mode).

[2] See [here](#EX) for information about how this is achieved.

[3] Limited to 5 levels of depth.

[4] These are dropped without warning because they can be removed without affecting the matching behavior.

[5] When targetting ES2018, \b and \B are replaced with a lookbehind/lookahead solution. For other targets, they are carried over as is, but generate a warning. They only recognize ASCII word chars in JavaScript, and neither the `u` nor the `v` flag makes them behave correctly.

<a name='EX'></a>
## How it Works

JsRegex uses the gem [regexp_parser](https://github.com/ammar/regexp_parser) to parse a Ruby Regexp.

It traverses the AST returned by `regexp_parser` depth-first, and converts it to its own tree of equivalent JavaScript RegExp tokens, marking some nodes for treatment in a second pass.

The second pass then carries out all modifications that require knowledge of the complete tree.

After the second pass, JsRegex flat-maps the final tree into a new source string.

Many Regexp tokens work in JavaScript just as they do in Ruby, or allow for a straightforward replacement, but some conversions are a little more involved.

**Atomic groups and possessive quantifiers** are missing in JavaScript, so the only way to emulate their behavior is by substituting them with [backreferenced lookahead groups](http://instanceof.me/post/52245507631/regex-emulate-atomic-grouping-with-lookahead).

**Astral plane characters** convert to ranges of [surrogate pairs](https://dmitripavlutin.com/what-every-javascript-developer-should-know-about-unicode/#24surrogatepairs) when targetting ES2009 (which doesn't support astral plane chars).

**Properties and posix classes** expand to equivalent character sets, or surrogate pair alternations if necessary. The gem [regexp_property_values](https://github.com/jaynetics/regexp_property_values) helps by reading out their codepoints from Onigmo.

**Character sets a.k.a. bracket expressions** offer many more features in Ruby compared to JavaScript. To work around this, JsRegex calls on the gem [character_set](https://github.com/jaynetics/character_set) to calculate the matched codepoints of the whole set and build a completely new set string for all except the most simple cases.

**Conditionals** expand to equivalent alternations in the second pass, e.g. `(<)?foo(?(1)>)` expands to `(?:<foo>|foo)` (simplified example).

**Subexpression calls** are replaced with the conversion result of their target, e.g. `(.{3})\g<1>` expands to `(.{3})(.{3})`.

The tricky bit here is that these expressions may be nested, and that their expansions may increase the capturing group count. This means that any following backreferences need an update. E.g. <code>(.{3})\g<1>(.)<b>\2</b></code> (which matches strings like "FooBarXX") converts to <code>(.{3})(.{3})(.)<b>\3</b></code>.

## Contributions

Feel free to send suggestions, point out issues, or submit pull requests.

## Outlook

The gem is pretty feature-complete at this point. The remaining unsupported features listed above are either impossible or impractical to replicate in JavaScript. The generated output could still be made more concise in some cases, through usage of the newer `s` or `v` flags. Finally, `ES2018` might become the default target at some point.
