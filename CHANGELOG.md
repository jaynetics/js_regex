# Changelog

## v2.2.0
### Added
- added support for the most recent unicode age properties (BMP parts only)

### Fixed
- fixed handling of \p{Pc}, \p{Nl} and several other, older unicode properties; thanks to https://github.com/mojavelinux

## v2.1.0
### Added
- added support for option groups and switches ("(?-m:.)", "(?i)a", etc.)
- added warning for unsupported encoding options ("(?d:\w)", "(?u)", etc.)

### Fixed
- fixed handling of whitespace following x-switches ("(?x)", "(?-x)")

## v2.0.0
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

## v1.2.3
### Fixed
- fixed handling of escaped parentheses ("\\(" and "\\)"); thanks to https://github.com/owst
- fixed handling of codepoint lists (e.g. \u{61 63 1F601}}.

## v1.2.0
### Added
- added support for hex escapes in character sets.

### Fixed
- fixed an exotic bug with multiple stacked quantifiers (e.g. /a{2}{3}{4}/). they are now all removed instead of breaking the regex.

## v1.1.0
### Added
- added support for astral plane literals outside of sets by converting them to surrogate pairs
- added support for the backspace pseudo set ([\b])
- added support for surrogate properties, (e.g. \p{surrogate})

### Fixed
- fixed a bug with atomic groups nested in atomic groups. they are now made non-atomic with a warning instead of breaking the regex.
- fixed a bug with negated properties (\p{^...} and \P{...}) in sets. they are now correctly extracted from sets.

## v1.0.19
### Fixed
- fixed handling of escaped bol/eol anchors (\^ and \$); thanks to https://github.com/tomca32

## v1.0.18
### Fixed
- fixed handling of carriage return escape sequences ("\r"); thanks to https://github.com/mrcthms
