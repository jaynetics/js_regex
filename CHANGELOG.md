# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- enable frozen string literals (#42)

### Fixed

- handling of backreference numbers in conjunction with conditionals
  - e.g. `(a)?(b)(?(1)c|d)\2` expanded with a wrong number for the false branch
- thanks to https://github.com/slevithan for reporting all of the following:
- handling of backreferences to non-participating groups, e.g. `\1()` (#26)
- handling of backreference multiplexing, e.g. `(?<n>a)(?<n>b)\k<n>` (#28)
- handling of backreferences to subexp calls, e.g. `(?<a>[ab])\g<a>\k<a>` (#29)
- handling of indirect recursion, e.g. `(a\g<2>?b)(c\g<1>?d)` (#35)
- handling of UTF-8 hex escapes, e.g. `\xEF\xC0\xBB` (#37)
- improved extended grapheme type handling (`\X`) (#38)

## [3.13.0] - 2025-01-27

### Added

- support for forcing the 'd' and 'v' flags via the `options` argument

### Fixed

- fix handling of set members that need to be escaped in v-mode
  - thanks to https://github.com/dmke for the report
- thanks to https://github.com/slevithan for reporting all the following:
- more closely emulate `^` and `$` (`^` only for newer JS) (#30)
- handling of single digit hex escapes, e.g. `\xA` (#31)
- handling of quantified atomic groups, e.g. `(?>a){2}` (#34)
- handling of numeric backrefs followed by space and numbers in x-mode (#33)
- handling of recursive subexp calls and following backrefs (#36)
- made the conversions of `\R` and `\X` match atomically (#32, #38)

## [3.12.0] - 2024-11-02

### Added

- nicer substitution of hex types `\h` and `\H` in `i`-mode

## [3.11.1] - 2024-01-07

### Fixed

- nicer set rendering with the upcoming `character_set` 1.8.0 (cosmetic fix)

## [3.11.0] - 2023-03-23

### Added

- more lenient casting for the `target:` argument

### Fixed

- regression in 3.10.0 that caused the loss of some escapes in character sets
  - e.g. `[\^\-\.]` was converted to `[^-.]`; fixed to convert to `[\^\-.]`
  - thanks to https://github.com/slfrnkln for the report

## [3.10.0] - 2023-01-29

### Added

- `JsRegex::compatible?` for checking if a Regexp can be converted
- improved performance, particularly when dealing with character sets (`[...]`)

## [3.9.0] - 2023-01-24

### Added

- limited support for whole pattern recursion (`\g<0>`)

### Fixed

- SystemStackError with recursive group calls (`(a|b\g<1>)c`)

## [3.8.0] - 2022-09-25

### Added

- added an optional `target:` argument
  - `target: 'ES2009'`
    - is the default
    - does not make any changes from previous versions of `js_regex`
  - `target: 'ES2015'`
    - is compatible with all modern browsers (not with IE11 or below)
    - uses the `u` flag in some cases to avoid lengthy escape sequences
  - `target: 'ES2018'`
    - is compatible with most modern browsers, but only partially with Safari
    - supports lookbehinds (will cause JS errors in Safari, see README!)
    - supports keep marks (`\K` - again not for Safari)
    - adds better word-boundary anchor conversions (`\b`, `\B` - again not for Safari)
    - brings more concise representations of unicode properties, posix classes, etc.
    - preserves capturing group and backreference names (`(?<x>.)`, `\k<x>`)

### Fixed

- support for forcing the 's' flag via the `options` argument
- fixed handling of astral plane literals with a codepoint above `0xFFFFF` (basically just private use chars)

## [3.7.2] - 2022-05-27

- fixed handling of `{,m}` quantifiers; thanks to https://github.com/serch
- fixed `NoMethodError` when using possessive quantifiers together with conditionals

## [3.7.1] - 2021-12-14

### Fixed

- fixed error when using octal escapes (e.g. `\0`) in JS strict mode by converting them to hex escapes instead of passing through

## [3.7.0] - 2021-03-03

### Added

- added `JsRegex::Error` as a mixin to all errors (mostly parser errors) to simplify catching them
- added `JsRegex::new!` as a strict method that will raise if the input can not be fully converted

## [3.6.0] - 2020-12-02

### Added

- added support for chained/multiplicative quantifiers (`A{4}{6}`) by bumping `regexp_parser` dependency

## [3.5.1] - 2020-11-02

### Fixed

- fixed possible error with absence groups (`(?~`) on Ruby 3.x by tightening `regexp_parser` dependency

## [3.5.0] - 2019-06-16

### Added
- improved '.' substitution so that it matches "\r" and astral plane chars like in Ruby

### Fixed
- fixed loss of backslashes in some edge cases when passed a `String` source (as possible since v3.4.0)
- escaping of operational literal whitespace in x-mode is no longer carried over (cosmetic improvement)

## [3.4.0] - 2019-06-07

### Added
- added full support and more concise representations for astral plane sets and properties via `character_set`; thanks to https://github.com/singpolyma for the suggestion
- `JsRegex::new` can now also be called with a source `String` instead of a `Regexp`, e.g. `JsRegex.new('\h')`

### Fixed
- '/' is now correctly escaped if it occurs within sets (this only caused issues with `JsRegex#to_s` output); thanks to https://github.com/singpolyma for the report

## [3.3.0] - 2019-05-26

### Added
- added support for local encoding options ("(?u:\w)", "(?a)[[:word:]]")

## [3.2.0] - 2019-05-18

### Added
- added support for absence groups ("(?~foo)")

### Fixed
- fixed `#to_s` output being syntactically invalid in JS when converting an empty Regexp
- fixed missing codepoints in "\R" replacement (vertical tab, form feed, nextline)

## [3.1.1] - 2018-09-24

### Fixed
- relaxed unnecessarily strict dependency on character_set 1.0.x

## [3.1.0] - 2018-09-17

### Added
- added support for conditionals ("(a)?(?(1)b|c)")
- added support for forward-referring subexpression calls ("\g<+2>")

### Fixed
- empty alternation branches ("(a|)") are no longer removed since the potential for a zero-width match might be intended
- fixed conversion of astral plane literals with lengths greater than one
- fixed handling of locally case-insensitive literals (following e.g. "(?i)") with lengths greater than one
- fixed a rare bug where backreferences, atomic groups and subexpression calls weren't handled correctly if preceded by either the linebreak type ("\R") or an option group with children ("(?i:...)")

## [3.0.0] - 2018-09-04
Major refactoring adding [character_set](https://github.com/jaynetics/character_set) and [regexp_property_values](https://github.com/jaynetics/regexp_property_values) as dependencies.

### Changed
- changed default options: the `g` flag is no longer automatically set, use `JsRegex.new(//, options: 'g')` to force it (#5)
- changed handling of unicode properties (\p{...}) and posix classes ([:...:]); their replacements now match the same codepoints as the host ruby version
- changed required ruby version from 1.9.3 to 2.1.0

### Added
- added support for moderately sized astral plane properties (e.g. \p{emoji})
- added full support for set nesting (e.g. "[a[^123]]")
- added full support for set ranges (including non-literal, e.g. "[\x00-\b]")
- added support for astral plane set members
- added support for set intersections (e.g. "[a-z&&[^aeiou]]")
- added support for set intersections (e.g. "[a-z&&[^aeiou]]")
- added support for all types of subexpression calls (e.g. "(foo)\g<1>")
- added support for bell and escape shortcuts ("\a", "\e")
- added warnings for ranges and unicode properties with large astral plane parts

### Fixed
- fixed handling of escaped alternation chars a.k.a. pipes ("\\|")

## [2.2.2] - 2018-07-09
### Fixed
- fixed errors on new Ruby versions by upgrading regexp_parser dependency

## [2.2.1] - 2018-03-15
### Fixed
- fixed handling of superfluous forward slash escapes; thanks to https://github.com/JasonBarnabe for the cue
- fixed quantification of astral plane literals by wrapping their surrogate pair substitution in a passive group

## [2.2.0] - 2018-03-04
### Added
- added support for the most recent unicode age properties (BMP parts only)

### Fixed
- fixed handling of \p{Pc}, \p{Nl} and several other, older unicode properties; thanks to https://github.com/mojavelinux

## [2.1.0] - 2017-11-03
### Added
- added support for option groups and switches ("(?-m:.)", "(?i)a", etc.)
- added warning for unsupported encoding options ("(?d:\w)", "(?u)", etc.)

### Fixed
- fixed handling of whitespace following x-switches ("(?x)", "(?-x)")

## [2.0.0] - 2017-09-25
Major refactoring. Using Regexp::Parser instead of Regexp::Scanner internally allows for higher-level conversions.

### Changed
- word boundaries \b and \B now cause warnings (see README for details)

### Added
- added support for possessive quantifiers ("++", "\*+", etc.)
- added support for backreferences ("\2") following atomic groups
- added support for \k-style numeric backreferences ("\k'2'")
- added support for relative backreferences ("\k'-1'")
- added support for named backreferences ("\k'foo'")
- added support for the generic linebreak type \R
- added support for control and meta escapes ("\cX", "\C-X", "\M-X", "\M-\C-X", etc.)

### Fixed
- when dropping unsupported expressions, their quantifiers are now dropped as well
- fixed handling of hex types and backspace ("\h", "\H", "\b") within negated sets
- double-negated properties ("\P{^...}") are now correctly treated as positive
- conditionals are now replaced with passive instead of capturing alternation groups

## [1.2.3] - 2017-04-12
### Fixed
- fixed handling of escaped parentheses ("\\(" and "\\)"); thanks to https://github.com/owst
- fixed handling of codepoint lists (e.g. \u{61 63 1F601}}.

## [1.2.0] - 2016-12-05
### Added
- added support for hex escapes in character sets.

### Fixed
- fixed an exotic bug with multiple stacked quantifiers (e.g. /a{2}{3}{4}/). they are now all removed instead of breaking the regex.

## [1.1.0] - 2016-11-28
### Added
- added support for astral plane literals outside of sets by converting them to surrogate pairs
- added support for the backspace pseudo set ([\b])
- added support for surrogate properties, (e.g. \p{surrogate})

### Fixed
- fixed a bug with atomic groups nested in atomic groups. they are now made non-atomic with a warning instead of breaking the regex.
- fixed a bug with negated properties (\p{^...} and \P{...}) in sets. they are now correctly extracted from sets.

## [1.0.19] - 2016-11-15
### Fixed
- fixed handling of escaped bol/eol anchors (\^ and \$); thanks to https://github.com/tomca32

## [1.0.18] - 2016-09-04
### Fixed
- fixed handling of carriage return escape sequences ("\r"); thanks to https://github.com/mrcthms
