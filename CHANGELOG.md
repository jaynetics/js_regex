# Changelog

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
