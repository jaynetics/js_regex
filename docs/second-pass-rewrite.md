# SecondPass rewrite

Replace the ordered mutation pipeline with stable capture identities, explicit
analysis, and focused semantic lowering. Preserve the existing public boundary:
`SecondPass.call(tree)` mutates and returns the original root. Retain Ruby 2.6
syntax compatibility, existing targets, and warning behavior.

Current status: the experimental compiler handles all 100 benchmark case/target
combinations. The normal suite has 1,199 passing examples with the updated local
`regexp_parser` selected by the user's Gemfile change. Production still uses the
original SecondPass. The substitution audit also passes all 1,199 examples;
the unequal-offset keep-mark integration failure is resolved. Broader generated
coverage still identifies semantic gaps. The milestones below
retain historical measurements; the latest results and remaining work follow
milestone 19. Native RegExp output is retained by user decision; the documented
keep-mark limits are part of that contract rather than a wrapper migration gate.

## First milestone: compatibility and performance baseline

Implemented:

- A reusable corpus in `spec/support/second_pass_corpus.rb`, covering ordinary
  references, absent and empty captures, finite and unbounded repetition, nested
  retention, lazy overlapping alternatives, duplicate-name commitment,
  subexpression calls, assertions, atomics, numeric delimiters, and keep marks.
- Ruby/JavaScript comparisons of first-match text and position, plus capture
  arrays for cases where the existing output preserves that layout. Positions
  are normalized to UTF-16 units. The simple cases enumerate every string of
  length zero through four over `a` and `b`; difficult cases use regression
  inputs from the existing integration suite.
- A conversion harness accepting `pass:` without stubbing production constants
  or sharing the existing conversion cache. Tests verify that its source,
  options, and warnings agree with the production entry point for the corpus.
- A standalone benchmark accepting the same `pass:` interface. It measures
  SecondPass time/allocations separately from conversion time/allocations,
  generated source bytes, capture count, and JS construction/matching time.
  Each pass receives a fresh tree; cloning is outside the pass timing.

Run the focused checks:

```sh
bundle exec rspec spec/lib/js_regex/second_pass_corpus_spec.rb
bundle exec ruby -Ilib benchmark/second_pass.rb --iterations 10 --samples 3 > /tmp/second-pass.json
```

The benchmark includes finite bounds 2/4/8/16 and 1/2/3/4 nullable conditions.
Use `--target ES2009` to restrict a run. Results include runtime and dependency
versions and individual samples. JS calls have a one-second execution limit;
benchmark timeouts appear in the results. JS construction may use engine caches
and is not a measurement of cold compilation. The matching timings use short
successful and failing inputs, not a comprehensive backtracking stress test.

Initial baseline (Ruby 4.0.7, regexp_parser 2.13.1, mini_racer 0.22.2):

- Before changes: 536 examples, two failures in `converter/base_spec.rb`.
- Both existing failures concern reluctant comma intervals: `/a{1,3}?/` and
  `/\A(a{1,3}?)*\1\z/`. With the installed parser, the former parses as an
  optional passive group around `a{1,3}`. This needs investigation independently
  of SecondPass; do not change those expectations to make the baseline green.
- New corpus: 153 examples, all passing.
- Benchmark smoke run: 100 case/target combinations, two samples of three
  conversions each, no JS timeouts. Preliminary ES2009 output grows from 168 to
  3,990 bytes across the finite-bound cases and from 35 to 803 bytes across the
  conditional cases. The multiple-variable-capture lazy case emits 5,752 bytes
  and 28 captures. These are useful optimization targets, not performance gates.

## Second milestone: representation and emitter

Implemented in `lib/js_regex/second_pass/compiler/`:

- Immutable expressions with explicit sequences, choices, groups, repetitions,
  assertions, and atomic boundaries. Compound converter fragments remain opaque
  boundaries with traversable children. Omitted branches remain distinct from
  participating empty alternatives.
- Separate input capture identities and emitted occurrences. References bind to
  occurrences, including forward references. Existing history, duplicate-name,
  value-check, and conditional nodes retain their distinct meanings.
- Subtree copying creates new capture occurrences with the same logical identity,
  remaps internal references, and preserves external references. Unchanged
  immutable subtrees are shared.
- An importer for converter output and an emitter back to `JsRegex::Node`.
  Group numbers are assigned once in emitted order. Capture metadata and
  quantifier data survive the adapter without sharing mutable parser objects.
  Emission rejects duplicate occurrences and references to removed captures
  rather than guessing their meaning.

The adapter preserves the corpus trees structurally and produces the same source
after the existing SecondPass. The full suite can also run with the adapter
inserted before the existing pipeline:

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_spec.rb
bundle exec rspec --require ./spec/support/second_pass_round_trip.rb
```

There are 89 representation/adapter examples. The full suite, both normally and
with the adapter enabled, has 778 examples and only the same two baseline
failures. Lint passes for the new implementation and support files.

The production entry point is unchanged; these compiler files are loaded only
explicitly. This is a representation and boundary adapter, not yet a replacement
semantic compiler. The emitter can reconstruct intermediate condition/history
nodes for migration tests; those still need lowering before stringification.
Numeric-reference delimiting also remains in the existing pipeline. Input IDs
are the converter's IDs; subexpression-call relationships remain represented by
the converter's explicit history nodes. The importer deliberately rejects old
pipeline intermediate trees containing unresolved duplicate numeric IDs.

## Third milestone: analysis and optional-capture lowering

Implemented a phase-local analysis snapshot for definitions, reference counts,
value uses, participation checks, and conservative must/may capture sets.
Empty matching has three states (unconditionally possible, impossible, unknown);
assertions and opaque fragments are not assumed to match empty. This analysis
does not yet infer widths or character sets, or prove participation at individual
reference locations across loops.

`Continuation` specializes a tail with known capture participation and copies it
together with its prefix. This preserves bindings to newly copied captures and
external captures without renumbering. Specialization handles absent references,
capture-value checks, ordered histories and duplicate-name candidates, and known
conditionals. Discarded conditional branches keep disabled capture slots.

`LowerOptionalCaptures` is the first semantic rewrite. It handles `?`/`??` around
one possibly-empty capture when every use is in the local continuation. It
preserves present/absent preference, handles successive optional captures, and
does not move continuations across captures, assertions, atomics, or iterations.
It uses one analysis snapshot; no whole-tree restart or numeric renumbering is
needed. It remains experimental and is not invoked by the production entry point.

Validation includes exhaustive inputs of length zero through five over `a/b/c`
for 13 patterns. Twelve execute through the new lowering and emitter alone; the
duplicate-name case still uses the existing resolver after the new rewrite.
The full compatibility corpus also passes with this lowering before the old
pipeline. The 23 new examples cover shared reference subtrees, binding copies,
participation analysis, unknown emptiness, and boundary restrictions.
The full suite has 801 examples with only the two baseline failures; lint passes.

Unbounded nullable loops, overlapping lazy alternatives, and multiple retained
captures still use the old implementation. Passing those corpus cases does not
yet establish that the new continuation design can replace those loop rules.

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_lowering_spec.rb
```

## Fourth milestone: independent reference pipeline

`compiler/pipeline.rb` now exposes an opt-in `Compiler.call(tree)` that runs the
new importer, optional-capture lowering, reference resolution, emitter, and
numeric-reference delimiting. It returns the same root and leaves plain trees
untouched. It never invokes the old SecondPass. Unimplemented semantics raise
`Compiler::Unsupported` before changing the input tree; this is an experimental
development boundary, not a change to the public conversion policy.

Reference resolution tracks participation at each position: absent, present, or
uncertain after merging branches. Captures become present at their closing
boundary; negative assertions do not export their captures. Required references,
forward/self references, nonempty participation guards, static and dynamic
conditionals, capture histories, and duplicate-name commitment now have new
implementations. History selects the latest participating occurrence, whereas
duplicate-name references may try an older value when a newer value does not
match. Numeric delimiting runs after numbering and covers value references too.

The continuation specs now run the duplicate-name and discarded-conditional
cases through the new resolver as well. Another 39 examples exercise the
independent pipeline, including exhaustive strings of length zero through six
over `a/b/c` for 32 patterns, capture arrays, UTF-16 offsets, delimiters, and
failure without input mutation. The full suite has 840 examples and the same
two baseline failures. Focused checks and lint pass after optimization.

The compiler still rejects referenced captures inside repeated iterations,
uncertain participation of nullable captures not handled by the optional rule,
references inside lookbehind, capture semantics in opaque fragments, and keep
marks. Production still uses the original implementation.

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_pipeline_spec.rb
bundle exec ruby -Ilib benchmark/second_pass.rb --implementation compiler --target ES2009 > /tmp/compiler.json
bundle exec ruby -Ilib benchmark/second_pass.rb --implementation current --target ES2009 > /tmp/current.json
```

The benchmark reports unsupported cases explicitly instead of timing a legacy
fallback. The new pipeline handles 19 of the 33 ES2009 benchmark cases so far.
An initial run of ten conversions per sample and three samples measured these
median pass times and allocations on the same local environment:

| Case | Old ms | New ms | Old allocations | New allocations | Old/new source bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Required reference | 0.024 | 0.020 | 70 | 186 | 5 / 5 |
| Optional nonempty capture | 0.028 | 0.031 | 97 | 279 | 37 / 37 |
| Optional nullable capture | 0.123 | 0.175 | 405 | 927 | 23 / 23 |
| Duplicate-name commitment | 0.063 | 0.047 | 182 | 455 | 23 / 27 |
| Four nullable conditions | 11.507 | 2.316 | 22,526 | 15,498 | 803 / 803 |

These short runs are diagnostic, not release gates. The new pipeline reuses its
analysis snapshot when optional lowering leaves the tree unchanged, shares
unchanged expressions during reference resolution, and skips importing plain
trees. Allocation overhead on simpler patterns and excess grouping in generated
source remain optimization work; the rewrite is not uniformly faster yet.

## Fifth milestone: consuming bounded capture loops

`ExpandBoundedLoops` now expands finite repetitions whose bodies are proven
nonempty and whose capture behavior cannot stay in a native quantifier. Each
iteration receives fresh occurrences. References are rebound to ordered
histories using logical capture identity, without intermediate numeric
renumbering. Conditions inspect the copies collectively; duplicate-name
candidates retain a separate history per logical capture rather than flattening
their fallback semantics.

The resolver also retains native quantifiers when each successful, consuming
iteration necessarily updates every referenced capture and the body does not
reference those captures internally. This covers both finite repetitions and
simple unbounded repetitions such as `(a)+\1`; retained captures across skipped
unbounded iterations are still unimplemented.

The 24 new examples cover exhaustive short strings for finite bounds, captures
skipped by later iterations, internal references, conditional loop bodies,
nested finite loops, subexpression-call histories, duplicate names, variable
widths, and astral captures. At this milestone, lazy-order tests used correctly
quantified converter trees to isolate the parser's lazy comma-interval bug.
Milestone 7 removes those repairs after the user's parser update. Focused tests and lint passed;
the full-suite run before the last two subexpression fixtures retained only the
two baseline failures.

Repeated empty iterations remain unsupported. A differential probe also found
that a self-referential repeated capture such as `(a|\1b){2}\1` does not obey the
simple previous-occurrence model. Such loops now raise `Compiler::Unsupported`
rather than silently compiling to different matches. Capture-value inspection
across expanded copies also awaits dedicated handling.

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_bounded_loops_spec.rb
```

The compiler now handles 24 of 33 ES2009 benchmark cases. A local run using ten
conversions per sample and three samples measured the following median pass
times against the previous current-implementation baseline:

| Case | Old ms | New ms | Old allocations | New allocations | Old/new source bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Variable-width bounded retention | 0.444 | 0.323 | 1,916 | 2,488 | 300 / 220 |
| Bound 2 | 0.283 | 0.167 | 1,249 | 1,426 | 168 / 126 |
| Bound 4 | 0.434 | 0.303 | 1,644 | 2,352 | 423 / 282 |
| Bound 8 | 0.729 | 0.534 | 2,494 | 4,252 | 1,209 / 594 |
| Bound 16 | 1.468 | 1.300 | 4,462 | 8,265 | 3,990 / 1,239 |

Output is smaller and conversion faster in this sample, but allocations remain
higher. Production integration still waits for semantic coverage and a broader
performance review.

## Sixth milestone: nullable regions, empty iterations, and initial unbounded retention

The optional-capture pass is now `LowerNullableChoices`. It handles passive
groups, alternatives, conditionals, optional groups with multiple captures, and
sole nested choices inside enclosing captures. A continuation can move through
a passive boundary; a sole choice can move outside a capture only when every
arm retains the capture wrapper. It does not lift across a preceding expression
whose backtracking order could change.

Every copied region is checked for escaping references to all of its captures,
including captures defined in the continuation. This closes a hole in the
original scalar rule: duplicating a later capture whose reference lives outside
the region would leave that reference bound to a removed occurrence. Such
regions remain intact until a wider-scope rewrite can handle them safely.
Continuation specialization and copying still share one implementation. The
common scalar case lowers a closed continuation once before specializing its
two arms, avoiding repeated analysis of both copies.

Bounded expansion now handles possibly-empty iterations. Synthetic captures
record the remaining input; progress checks compare against the start two
iterations earlier, retaining Ruby's last empty capture when repetition stops.
The nullable-choice pass then specializes capture histories along the selected
paths. A 40-case matrix covers five body shapes, four bounds, and greedy/lazy
preferences. At this milestone, lazy fixtures still isolated the installed
parser bug; they now use the normal conversion path.

`LowerKeepMarks` handles the supported root-level marks, including multiple marks
and root alternatives. Converter warnings for unsupported targets and nested
marks remain unchanged. Prefixes containing references still encounter the
compiler's lookbehind restriction.

`PreserveDisjointLoops` adds the first unbounded retained-capture rule: one
nonempty capture alternating with a branch whose leading literal character is
disjoint. Each capture update is grouped with intervening skipped iterations,
so native repetition no longer clears its value. It covers greedy/lazy `*` and
`+`, required/optional references, and conditions. Unicode-aware case folding is
used conservatively when proving disjointness; overlapping branches, nullable
updates, multiple captures, and higher lower bounds remain outside this rule.

Validation: 902 examples in the full suite, only the same two baseline parser
failures, and lint passing. Tests include exhaustive short strings for the new
nullable regions and 48 unbounded-loop/body/continuation combinations. The
experimental pipeline handles 78 of 100 case/target benchmark combinations.
These counts describe the checked corpus, not overall regex support.

The generalized pass initially raised the four-condition case to about 6.6 ms
and 45,942 allocations. Reusing the scalar continuation reduced that local
sample to about 3.2 ms and 25,118 allocations, with the same 803-byte output.
The old baseline was about 11.5 ms and 22,526 allocations. Conversion gains do
not yet eliminate allocation overhead; performance work remains before rollout.

## Seventh milestone: unbounded loops and differential validation

The user's Gemfile now selects the updated local `regexp_parser`. Both previous
failures pass. Bounded-loop tests use the normal parser/converter path, including
the lazy empty-iteration matrix; no quantifier repair remains in the fixtures.

The compiler now includes:

- `LowerCaptureStates`: monotone participation states for constant capture
  values, or variable values used only by conditions. Same-state consuming
  iterations stay native; transitions to new states are acyclic. Ordered branch
  selection remains explicit, including duplicate-name commitment.
- `PreserveCaptureCycles` (formerly `PreserveDisjointLoops`): character-class and
  astral disjointness, plus overlapping regular capture bodies when an adjacent
  required reference proves that regrouping preserves matching order.
- `FlattenCharacterLoops`: nested greedy loops over distinct single characters.
  This deliberately excludes ambiguous boundaries and nested lazy repetition.
- `LowerNullableLoops`: unconditional nullable captures in greedy unbounded
  loops. Progress guards isolate consuming iterations; continuation probes keep
  the preferred empty ending ahead of later consumption. A separate final empty
  capture preserves Ruby's value and permits backtracking to the consuming tail.
- `LowerLazyRuns`: two disjoint greedy single-character runs inside a lazy loop,
  followed by their two required references in either order. Explicit histories
  retain both values. Continuation probes distinguish shortening the current run
  from taking later iterations. Every copied continuation owns fresh occurrences.
- Analysis of reads that lack a mandatory preceding update in their subtree.
  This permits native loops with references to captures set during the same
  iteration, including the converter's atomic-group wrappers, while rejecting
  reads that need unsupported earlier-iteration history. Loop-presence facts let
  ordinary patterns skip irrelevant rewrite passes.
- `SimplifyLazyLoops`: when the entire continuation is guaranteed to succeed,
  a lazy loop needs only its minimum number of iterations. This proof follows
  enclosing continuations rather than assuming a locally empty tail suffices.
  It also preserves the simple capture layout for `(?:(a+)|ab)+?\\1?` without
  introducing state-machine capture copies.

These rules do not delegate to the old pipeline. Coverage is 100/100 benchmark
combinations; this is a corpus result, not a claim of general regex support.
The full suite has 1,001 examples and no failures; lint passes with Ruby 2.6 as
its syntax target. Runtime validation so far uses Ruby 4.0.7, not the full runtime
matrix. Capture arrays are compared where the generated layout is preserved;
other semantic comparisons check first-match text and UTF-16 position.

`benchmark/second_pass_differential.rb` generates reproducible combinations of
capture bodies, quantifiers, references, and conditional tails. Each implementation
is compared with Ruby independently. Failures shrink by deleting input chunks
and removing generated pattern features; invalid or unsupported reductions are
excluded. Unsupported cases, mismatches, JS errors, and Ruby execution timeouts
have separate result statuses. Timeouts are harness limits, not compiler policy.

The 866-pattern sweep (seed 1729) across all three targets produced:

| Implementation | Matching Ruby | Unsupported | Mismatches | Ruby timeouts |
| --- | ---: | ---: | ---: | ---: |
| Original | 2,412 | 0 | 156 | 30 |
| Compiler | 2,139 | 459 | 0 | 0 |

A second compiler-only sweep with seed 2718 and 474 input strings produced
2,142 passes, 456 unsupported cases, and no mismatches. Seeds vary anchoring and longer
inputs; these are not 866 independent regex grammars. Original-pipeline failures
remain visible in the report, rather than being treated as the compiler's oracle.
For example, `(a|)+?\\1` on `a` shrinks to an old-pipeline empty-match discrepancy.
Several unsupported compiler cases overlap those original limitations.

The benchmark now avoids marshalling JS RegExp objects back into Ruby during
construction timing. Its optional `--stress` cases exercise longer failing inputs
at three lengths, with the existing per-JS-call timeout reported explicitly.

Isolated local runs with ten conversions per sample and three samples measured
these median ES2009 pass times (before the final lazy-loop simplification):

| Case | Old ms | New ms | Old/new allocations | Old/new source bytes |
| --- | ---: | ---: | ---: | ---: |
| Required reference | 0.021 | 0.030 | 70 / 227 | 5 / 5 |
| Nullable capture | 0.123 | 0.177 | 403 / 1,590 | 23 / 23 |
| Nested retention | 3.828 | 2.994 | 25,600 / 2,250 | 361 / 45 |
| Multiple lazy captures | 5.108 | 2.962 | 13,205 / 19,813 | 5,752 / 2,011 |
| Bound 16 | 1.531 | 1.075 | 4,451 / 9,056 | 3,990 / 1,239 |
| Four nullable conditions | 14.642 | 3.912 | 22,496 / 29,773 | 803 / 803 |

The stress run identified redundant partitions in skipped lazy character runs.
Replacing `(x+)*?` with `(x+)??` in those capture-free prefixes preserves the
first-visit order of input positions. The lazy-run failure case with 16 characters per run
improved from a timeout to roughly 0.08 ms/input; length 64 took roughly 3 ms.
Length 256 still timed out, as did nullable failure lengths 64 and 256. These
are matching-performance gaps, despite passing the semantic corpus. Times use
20 matches per JS call and a one-second call timeout; they are diagnostic samples.
The original implementation also timed out on the nullable 64/256 cases and on
all three lazy-run failure cases in the matching comparison.

```sh
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --patterns 866 > /tmp/differential.json
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --seed 2718 --patterns 866 --implementation compiler > /tmp/compiler-differential.json
bundle exec ruby -Ilib benchmark/second_pass.rb --implementation compiler --stress --target ES2018 --iterations 1 --samples 1 > /tmp/compiler-stress.json
```

## Eighth milestone: enclosing captures, empty updates, and scope boundaries

The compiler now handles enclosing captures around retained-capture cycles and
lazy disjoint runs. Referenced enclosing captures retain the last original
iteration, including when their references follow the primary references.
Consuming unbounded repetitions with a lower bound above one expand their finite
required prefix, then use the existing unbounded rules. State-machine conditions
can retain unresolved participation checks from that prefix.

`RequireCaptures` removes optional bypasses when a required reference makes them
fail anyway. This handles cases such as `(a*(b*)?)\2` without copying an enclosing
capture or moving a backtracking prefix. The rule excludes assertions, atomic
boundaries, and repeated iterations, where forcing participation could change
committed choices or previously retained values. Tightened ancestors discard
stale nullable metadata.

Nullable-loop work includes disjoint alternative bodies with safe continuations,
nested optional captures such as `((a)?)+`, and lazy nullable reference tails such
as `(a*)+?\1`. The last rule also handles longer continuations, optional
references, and multiple independent runs, preserving the original capture
arrays. Required references retain the final empty value; optional references
retain the preferred first iteration or an initially absent capture. The tail
must not read this capture elsewhere. Applicability is deliberately narrower
than all nullable loops: failed empty updates and
later backtracking can change which iteration Ruby accepts.

Finite nullable repetition now tracks capture updates as well as input progress.
`EmptyIteration` distinguishes an absent/nonempty previous value, an empty value
at the same position, and an empty value at a different position. Synthetic
aliases bind these checks to exact copies; `CaptureHistories` separately resolves
the original logical references. This fixes the minimized case
`(?:(a*)|b|c){1,3}(?(1)b|a)\1?` on `cbb`. A smaller position-only rule remains for
the proven case where one capture covers the whole iteration. It halves
allocations in the bounded-empty benchmark compared with the general rule.
Shared region checks reduce that overhead further, although allocations and
source size remain higher than the original implementation in this case.

Value checks across split captures now select the latest participating copy,
including a later empty value. A completely absent history succeeds empty, as
required for a raw value check. Required references retain their distinct failure
behavior. Bounded greedy/lazy cases and negative assertions exercise the
converter-tree boundary against equivalent Ruby conditional expressions.

Two other ordered-backtracking regressions are now covered: a variable-width
skipping branch can invalidate an absent-first cycle transformation, and an
overlapping continuation can invalidate nullable-loop factoring. Fixed-width
and continuation checks prevent applying those rules outside their proven
cases. Unsupported paths raise before mutating the caller's root.

Keep-mark prefixes can now inline known constant internal references in the
generated lookbehind, preserving capture arrays and match positions. External
references retain their runtime values. Variable internal values and uncertain
participation remain unsupported because JavaScript evaluates lookbehind
backwards. Absence groups have an explicit IR boundary; their captures do not
export participation. Absence bodies containing backreferences currently expose
a separate parser cloning issue before SecondPass. Those two regression tests
therefore exercise converter trees directly, without changing the dependency.

Shared `CharacterFacts` caches parsed leaves, first-character sets, and width
proofs; generated subtrees are not serialized and reparsed. Region closure checks
compose existing analysis summaries rather than reanalyzing temporary wrapper
trees, and passive-wrapper inspection is shared across passes. Generated native
repetitions are marked explicitly after a lowering rule proves their capture
clearing behavior. Imported repetitions always undergo the normal safety checks.

Validation:

- Ruby 4.0.7: 1,058 examples, no failures.
- Ruby 2.6.10: 1,057 examples, no failures, four pending oracle comparisons. Three concern
  Ruby's pre-3.1.3 duplicate-name backreference bug. The existing suite already
  gates another example for that engine bug. The fourth isolates older engines'
  rewriting of directly nested quantifiers during Regexp compilation. It checks
  the engine behavior before skipping; the compound-body continuation matrix
  still runs on all versions. The compiler retains modern semantics.
- Lint: 42 implementation, harness, and spec files pass with Ruby 2.6 syntax.
- The expanded generator covers 1,498 patterns across three targets and 474
  input strings. Seed 2718 produces 3,276 passes, 1,218 explicit unsupported
  cases, and no mismatches, errors, or timeouts. This larger grammar includes
  enclosing captures and lower bounds above one; its unsupported count is not
  directly comparable with the smaller milestone-7 grammar. Seed 1729 uses 475
  inputs and produces 3,282 passes, 1,212 unsupported cases, and no mismatches.
- The opt-in `spec/support/second_pass_compiler.rb` substitution leaves 16 old-suite failures,
  principally exact-source snapshots and step-isolation expectations. The actual
  semantic regressions previously exposed by that audit now pass. This does not
  replace the wider coverage and performance requirements for switching.

Isolated benchmark medians (ten conversions per sample, three samples, ES2009):

| Case | Old ms | New ms | Old/new allocations | Old/new source bytes |
| --- | ---: | ---: | ---: | ---: |
| Required reference | 0.021 | 0.030 | 70 / 229 | 5 / 5 |
| Optional capture | 0.028 | 0.047 | 96 / 401 | 37 / 5 |
| Nullable capture | 0.123 | 0.070 | 403 / 660 | 23 / 8 |
| Bounded empty iterations | 1.760 | 1.329 | 5,098 / 12,620 | 97 / 116 |
| Nested retention | 3.828 | 3.035 | 25,600 / 2,373 | 361 / 45 |
| Multiple lazy captures | 5.108 | 3.059 | 13,205 / 18,832 | 5,752 / 1,875 |
| Bound 16 | 1.531 | 1.034 | 4,451 / 8,859 | 3,990 / 1,119 |
| Four nullable conditions | 14.642 | 2.786 | 22,496 / 20,941 | 803 / 803 |

These compare against the same original baseline used above; timings are local
diagnostics, not stable performance guarantees. The new implementation has about
2,489 lines versus 1,905 in the original. Focused passes improve separation of
concerns, but the requested conciseness goal has not yet been met. Review and
consolidation are necessary before calling the rewrite complete.

```sh
bundle exec rspec
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --patterns 1498 --seed 2718 --implementation compiler > /tmp/compiler-differential.json
bundle exec ruby -Ilib benchmark/second_pass.rb --implementation compiler --iterations 10 --samples 3 > /tmp/compiler-benchmark.json
# Expected migration failures remain in old source/step-specific specs:
bundle exec rspec --require ./spec/support/second_pass_compiler.rb
```

## Ninth milestone: variable skips and simpler nullable runs

Greedy retained-capture cycles now allow variable-width skipping iterations when
their complete character alphabet is disjoint from the capturing branch's
starting characters. `CharacterFacts#alphabet` uses cached leaves and refuses
assertions or unknown fragments. This stronger condition ensures that shortening
a skip cannot expose another capture update. Fixed-width checks remain necessary
for lazy loops; the earlier `bbac` ordering regression still passes. A separate
regression rejects greedy skips such as `ba?`, which could expose `a` after
shortening, including case-insensitive variants.

`SimplifyLazyLoops` is now `SimplifyLoops`. Its greedy-star rule also handles
greedy outer repetitions and required minimum counts above one, including lazy
minimums such as `{2,}?`. It preserves the original capture arrays when nested
captures cover exactly the same run. The proof still requires a single adjacent
positive value use, no other reads of these captures, a regular consuming star
body, and no possessive boundary. Arbitrary nullable bodies and capture-dependent
continuations retain their existing lowering or unsupported behavior.

The simplifier examines the original reference pair even if recursive rewriting
has removed a lazy optional reference. Otherwise the match could remain correct
while JavaScript reports the wrong final capture value. The expanded continuation
matrix caught that interaction and now compares full capture arrays across all
three targets, greedy/lazy repetitions, optional references, and higher minimums.

The standard final-empty-iteration case, `\A(a*)*\1\z`, now emits six source bytes:

| Implementation | Pass ms | Allocations | Source bytes |
| --- | ---: | ---: | ---: |
| Original | 0.309 | 880 | 111 |
| Compiler before this milestone | 0.226 | 1,996 | 115 |
| Compiler now | 0.086 | 674 | 6 |

These are local ES2009 medians with ten conversions per sample and three samples.
The nullable failure stress case now finishes at lengths 16, 64, and 256, taking
roughly 0.002 ms/input on ES2018. The last two lengths previously timed out.
This improvement applies to the proven greedy-star subset; it does not eliminate
backtracking throughout the compiler. The two-capture lazy-run case still takes
about 3 ms/input at length 64 and times out at 256 under the one-second batch
limit. All 100 standard benchmark case/target combinations remain supported.

Validation:

- Ruby 4.0.7: 1,062 examples, no failures.
- Ruby 2.6.10: 1,061 examples, no failures, the same four oracle skips.
- Lint: all 42 implementation, harness, and spec files pass.
- On the previous 1,498-pattern grammar, seeds 2718 and 1729 produce respectively
  3,354/1,140 and 3,360/1,134 passing/unsupported target combinations, with no
  mismatches. This is 78 more passing combinations per seed than milestone 8.
- The generator now includes variable skips, skips that can expose a capture
  start, and nested equal captures. On all 1,696 patterns and three targets,
  seed 2718 produces 3,798 passes and 1,290 unsupported cases; seed 1729 produces
  3,789 passes and 1,299 unsupported cases. Neither sweep reports mismatches,
  errors, or timeouts. They use 474 and 475 inputs respectively.
- The opt-in production substitution still has 16 source/step-specific migration
  failures. Production remains on the original implementation.

The compiler now has 2,523 lines. Broader support and smaller generated patterns
have not yet fulfilled the implementation-size goal; consolidation remains work.

```sh
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --patterns 1696 --seed 2718 --implementation compiler > /tmp/compiler-differential.json
bundle exec ruby -Ilib benchmark/second_pass.rb --implementation compiler --stress --target ES2018 --iterations 1 --samples 1 > /tmp/compiler-stress.json
```

## Tenth milestone: captured segments and nullable participation states

`SplitCaptureValues` handles nullable choices behind backtracking prefixes inside
enclosing captures. It leaves each prefix in its original position and captures
consecutive segments, then reconstructs the original value through ordered
references to those segments. Existing captures and already split nested values
are reused when they cover a whole segment. This avoids moving a later choice
ahead of the prefix's backtracking. It also lets the bounded-loop empty-update
checks operate on formerly inaccessible inner captures.

Cases now supported include `(a*(b*)?)\2?`, `(a*(b*)?)\1\2?`, nested enclosing
captures, optional enclosing captures observed by conditions, and bounded forms
such as `(a*(b*)?){1,3}\1`. Raw value checks reconstruct the same string and still
succeed empty when all segments are absent. The pass excludes self-reads before
the original capture closes and values selected through duplicate-name/history
candidates, which currently require scalar representations.

Segmentation preserves matching and logical reference values, but changes the
emitted JavaScript capture-slot layout. Those cases are compared by full-match
text and position, not by assuming Ruby-compatible group arrays. This remains an
explicit migration concern. Trees without nested captures take a fast path;
unchanged trees do not undergo the reference-reconstruction traversal.

`LowerCaptureStates` now handles nullable iterations when one capture covers the
whole body and only participation, or a constant empty value, is observed. It
separates consuming and empty paths in their original order. Empty paths stop
once the participation state is unchanged; equivalent stopping choices are not
repeated on both sides of the consuming loop. This supports greedy and lazy
forms of `(a*)`, `(a*?)`, `(a|)`, `(|a)`, optional bodies, and bounded inner runs
with conditional continuations. It deliberately excludes general empty values
retained across skipping iterations, where position history is still required.

The new tests also exposed an open-capture state bug. Opening a capture clears its
own participation until it closes, so a condition inside it must not observe a
previous iteration as present. Both path construction and substitution now honor
that boundary. For example, `(a?(?(1)|b?))*(?(1)a|b)` correctly matches all of `bba`.
The regression matrix covers conditionals without an else branch and captures
created in the continuation, as well as self-conditions in consuming loops.

Validation:

- Ruby 4.0.7: 1,086 examples, no failures.
- Ruby 2.6.10: 1,085 examples, no failures, the same four oracle skips.
- Lint: all 44 implementation, harness, and spec files pass.
- On the preceding 1,696-pattern grammar, segmentation changes 36 combinations
  from unsupported to passing for seed 2718; none change in the other direction.
  It removes every uncertain-nullable-participation failure from that sweep.
- The generator now includes overlapping prefixes and lazy inner choices,
  for 1,894 patterns across three targets. With 475 inputs per seed, seed 2718
  produces 4,134 passes and 1,548 unsupported cases; seed 1729 produces 4,143
  passes and 1,539 unsupported cases. Neither reports mismatches, errors, or
  timeouts. Nullable participation states account for 30 additional passing
  combinations per seed after segmentation.
- The opt-in production substitution still has 16 migration failures involving
  original source snapshots and step-specific expectations.
- All 100 standard benchmark combinations remain supported. Common simple-case
  allocations are unchanged: 229 for a required reference, 660 for an optional
  nullable capture, and 674 for the simplified final-empty-iteration case.

The compiler now has 2,648 lines, so implementation-size consolidation remains
unfinished. Production still uses the original implementation.

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_split_values_spec.rb spec/lib/js_regex/second_pass/compiler_capture_states_spec.rb
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --patterns 1894 --seed 2718 --implementation compiler > /tmp/compiler-differential.json
```

## Eleventh milestone: migration audit and quantifier reuse

The opt-in adapter now honors tests that explicitly replace `STEPS`. Those unit
tests continue exercising the selected legacy step; ordinary conversions use
the new compiler. Fourteen of the previous sixteen substitution failures came
from ignoring that test setup. The two remaining integration snapshots now
check matching and warnings instead of requiring the old generated source.
This made the substitution audit pass all 1,086 examples before the new
keep-mark guard below. It does not establish compatibility for every pattern,
nor does it run legacy step-isolation assertions against the new compiler.

The README now states the existing capture-layout limitation: expansions can
change capture counts and numbering. Internal references are updated, but JS
`exec` group indices need not correspond to the original Ruby groups. The
segmentation pass still needs review against that contract; the documentation
does not excuse incorrect match values or positions.

Generated quantifiers now reuse a finite set of immutable `Quantity` objects.
Arbitrary bounds are constructed normally, without an unbounded cache. Emission
continues to construct independent mutable parser quantifiers. Keep-mark
lowering also avoids rebuilding trees that contain no keep marks.

Median SecondPass allocations on ES2009, with ten iterations and three samples:

| Case | Before | After |
| --- | ---: | ---: |
| Required reference | 229 | 224 |
| Nullable capture | 660 | 652 |
| Nullable conditional | 1,876 | 1,811 |
| Bounded empty iterations | 12,630 | 12,464 |
| Multiple lazy captures | 18,844 | 18,203 |
| Four nullable conditions | 20,941 | 20,415 |

All 100 standard combinations remain supported. These savings do not eliminate
the allocation regressions against the legacy implementation recorded above.

### Keep-mark correctness boundary

Additional probes exposed cases where converting a prefix directly to
lookbehind is incorrect:

- `/a+\Ka/` on `aaa` must return the `a` at offset 2; the old rewrite returns
  offset 1 because the prefix's greediness no longer selects the returned start.
- `/a\Kba|ab/` on `aba` must return `ba`, but the old rewrite returns `ab`.
- `/(?:(a)|(a))\K(?(1)c|a)/` on `aa` must backtrack into the prefix; lookbehind
  commits its first choice and loses the match.
- `/([ab]){2}\K\1/` on `abb` must retain the last forward capture. JavaScript's
  backward evaluation instead retains the first one. Even literal repeated
  captures can differ in their actual casing under case-insensitive matching.

The experimental compiler now rejects unproven prefixes before modifying the
input tree. Its first-match subset accepts linear literal prefixes, fixed
uncaptured repetitions, constant internal reference values, and equal keep
offsets across root alternatives. This is deliberately conservative: some
rejected patterns are equivalent, but a width check alone is insufficient.
Empty kept matches and multiple keep marks remain covered by the positive
matrix. No production fallback or warning policy has changed.

Global matching has a further unresolved boundary even within that first-match
subset: `/a\Ka/` scans `aaa` once in Ruby, while `/(?<=a)a/g` finds two matches,
reusing a prefix consumed by the previous match. The existing differential
corpus checks first matches, so it cannot establish global keep-mark behavior.
This needs an explicit solution or compatibility decision before rollout.

Validation:

- Ruby 4.0.7 normal suite: 1,087 examples, no failures.
- Ruby 2.6.10: 1,086 examples, no failures, four existing oracle skips.
- Lint: 46 implementation, harness, and affected spec files pass.
- Substitution audit: 1,087 examples, one failure in the integration example
  mixing kept and ordinary root alternatives. The guard rejects its unequal
  offsets; the test is retained unchanged. This is a real coverage gap,
  distinct from the previous test-adapter failures.
- Compiler implementation: 2,712 lines; whole-implementation concision remains
  unfinished. Production still uses the original pipeline.

## Twelfth milestone: mixed keep offsets and global comparisons

The compiler now accepts literal root alternatives with unequal keep offsets
when their overlaps prove that lookbehind preserves the result. The integration
example for `/a\Kb|c/`, `/c|a\Kb\Kc/`, and `/a\Kb|c\Kd/` passes unchanged. The
audit adapter still routes ordinary conversions through the compiler; no test
or production fallback was added.

The proof compares complete literal words at every relative start that could
reverse their original search order. A tie at the returned start can select a
different alternative only if both return the same substring and there are no
captures. For example, `/c|ab\Kc/` is equivalent, but `/(c)|ab\Kc/` is rejected:
the first match on `abc` would otherwise change the captured group from absent
to `c`. Linear captures are accepted where branch selection is preserved.

The same proof rejects global matches that could reuse a prefix consumed by a
previous match. `/a|a\Kb/` and `/a\Ka|b/` are examples that need this additional
check even when first-match ordering is correct. Empty matches include the
one-character advance before the next search. The newly admitted mixed-offset
subset uses ASCII literal words; overlap checks allow either case because the
tree does not carry the final JavaScript `i` flag. Unknown words and non-ASCII
folding remain outside this proof. Output remains the compact lookbehind form.

This does not solve general keep marks. In particular, the existing equal-offset
path still has the global limitation recorded in milestone 11, and variable
prefix greediness, prefix backtracking, and reversed capture direction remain
unsupported. First-match tests cannot establish those semantics.

The shared comparison harness now supports global scans, including match
positions, capture arrays, per-input reset, and Unicode advancement after empty
matches. The generator gains a separate `keeps` grammar and a `--global` mode;
its existing capture grammar and default first-match behavior are unchanged.
Generated case-insensitive failures retain their options when minimized and
reported.

Validation:

- Normal suite and compiler substitution audit: 1,118 examples each, no failures.
- Ruby 2.6.10: 1,117 examples, no failures, the same four oracle skips.
- Lint: 48 implementation, harness, and affected spec files pass.
- The keep grammar enumerates 1,772 ordered pairs with unequal keep offsets.
  Each seed varies case sensitivity and input casing; seed 1729 has 1,356 inputs,
  and seed 2718 has 1,355. Both first-match and global runs produce 86 passing
  patterns and 1,686 explicitly unsupported patterns, with no compiler
  mismatches, errors, or timeouts. The focused specs also cover three-way choices
  and capture arrays, including case-insensitive matches.
- For comparison, the legacy pipeline has 1,630 global mismatches in the same
  seed-2718 grammar. This is a targeted keep-mark grammar, not a measurement of
  overall library compatibility.
- The 1,894-pattern capture grammar on seed 1729 retains its 4,143 passing and
  1,539 unsupported target combinations, without mismatches, errors, or timeouts.
- All 100 standard benchmark combinations remain supported. Representative
  allocation counts are unchanged: 224 for a required reference, 18,203 for
  multiple lazy captures, and 440 for the simple keep-mark case.
- The compiler now has 2,753 lines. Whole-implementation concision and the
  remaining semantic gates still prevent a production switch.

```sh
bundle exec rspec --require ./spec/support/second_pass_compiler.rb
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --suite keeps --implementation compiler --patterns 10000 --seed 1729
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --suite keeps --global --implementation compiler --patterns 10000 --seed 1729
```

## Thirteenth milestone: lazy scalar loops with empty-first bodies

`LowerNullableLoops` now handles lazy stars and pluses when a single capture
covers the entire iteration and its body unconditionally tries an empty match
first. Examples include `(a*?)*?\1`, `(|a)*?\1a`, `(a??)*?(?!\1)a`, and
`(a*?b*?)*?\1a`. Continuations may read the value more than once, use conditions,
or create further captures. References must stay within the lowered region.

The lowering tries the continuation with the current value, then with an empty
update, then tries another consuming iteration. Empty updates at the same
position add no distinct outcomes in this scalar case. A consuming iteration
always overwrites the capture, so an earlier empty value cannot survive across
skipping iterations. The consuming prefix uses a native lazy star, whose own
progress rule already excludes empty iterations; no synthetic position capture
or progress assertion is needed. This preserves the order of choices while
avoiding unnecessary generated syntax and state.

Segmentation now leaves captures intact when their nullable values are read only
inside the enclosing capture. Previously it could insert a new boundary between
the loop and its continuation, preventing this lowering. Escaping reads and
bounded empty-loop instrumentation still require segmentation. This enables
enclosing cases such as `((a*?)*?\2a)\1` without splitting the enclosing value.
ES2009 surrogate-pair fragments are checked locally for positive consumption;
general opaque scopes retain their existing boundaries.

The new proof deliberately excludes multiple retained captures, skipping arms,
minimum counts above one, bodies that prefer consuming before empty, and nested
repetitions of nullable bodies. The last restriction matters independently of
capture retention: JavaScript can skip an empty inner iteration and try a
consuming alternative where Ruby stops. For example, `((?:|a)*)+?\1?` on `a`
previously converted to a pattern returning `a`, whereas Ruby returns empty.
`ResolveReferences` now rejects unlowered greedy repetitions of capture-free,
empty-first bodies instead of silently accepting that known ordering gap,
including when simplification has removed the original outer loop.

Validation:

- Normal suite and compiler substitution audit: 1,134 examples each, no failures.
- Ruby 2.6.10: 1,133 examples, no failures, four existing oracle skips.
- Lint: all 49 implementation, harness, and affected spec files pass.
- Focused coverage includes all three targets, enclosing captures, internal and
  external references, conditional continuations, case-insensitive matching,
  astral characters, and first/global comparisons for 320 pattern variations.
- On the unchanged 1,894-pattern capture grammar, seed 1729 now has 4,194 passing
  and 1,488 unsupported target combinations; seed 2718 has 4,188 passing and 1,494
  unsupported combinations. These are gains of 51 and 54 respectively. Neither
  sweep loses a previously passing case or reports a mismatch, error, or timeout.
- All 100 standard benchmark combinations remain supported. Common-case
  allocations remain 224 for a required reference, 652 for a nullable capture,
  and 12,464 for bounded empty iterations.

This adds supported semantics, not general empty-history handling. Generated
capture layouts may still differ, and the compiler now has 2,810 lines, so the
whole-implementation concision goal remains open. Production is unchanged.

For `\A(a*?)*?\1a\z`, removing the redundant progress tracking reduces the new
lowering from 81 to 58 source bytes and from 2,001 to 1,797 median SecondPass
allocations. The legacy output uses only 15 bytes and 171 allocations, but misses
Ruby's successful empty-update match on `aa`; it is not equivalent. Conversion
cost remains higher. Both implementations still reach the one-second JS timeout
on failing inputs of 32 and 64 `a` characters followed by `c`, for this pattern
and the corresponding `a*?b*?` body. Performance work must address those cases
without dropping required semantics or imposing expansion limits.

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_lazy_nullable_loops_spec.rb
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --implementation compiler --patterns 1894 --seed 1729
```

## Fourteenth milestone: capture-free empty-loop normalization

`SimplifyLoops` now handles regular repeated bodies that contain no captures or
references and unconditionally try empty first. Ruby stops at that empty
iteration even below a required minimum. After its continuation fails, consuming
paths are tried in lazy order. With no capture or reference effects, duplicate
empty visits add no distinct outcomes. A native lazy repetition with minimum
zero therefore preserves that order; finite maximum counts are retained.

This covers greedy and lazy bounded/unbounded repetitions, as well as greedy
optional groups. For example, `(?:|a)?a` must match only the first `a` in `aa`;
JavaScript's unmodified greedy optional can instead consume both characters.
The normalization also resolves the two explicitly rejected cases from milestone
13: `((?:|a)*)+?\1?` and `((?:a*?b*?)*)+?\1?` both simplify to `()\1?` when
their first empty value already satisfies the continuation. Otherwise the body
remains available for backtracking. Bounds and capture arrays are checked
against Ruby rather than inferred from generated source.

Normalization runs inside the existing simplification phase. Nested bodies are
processed before their parents, and the lazy nullable-capture lowering accepts
the resulting inner loops. This enables patterns such as
`((?:a*?b*?)*)*?\1a` without adding another pipeline pass or unrolling repetitions.
It does not reset minimum counts on capturing iterations: those retain their
separate empty-update/history requirements.

A cheap initial screen now detects potentially empty quantified groups even
when the pattern has no references. This prevents plain patterns from bypassing
the correction. Literal runs and wholly consuming groups still return their
original tree without allocating the IR. Analysis records only capture-free,
reference-free bodies known to allow empty matches as normalization candidates,
avoiding extra work for optional backreferences.

The rule stays within passive and capturing containers. Bodies with references,
captures, assertions, atomic behavior, or an unproven first empty path are not
normalized. Unhandled empty-first repetitions inside assertions continue to
raise before mutating the input; that check now includes greedy optionals.

Validation:

- Normal suite and compiler substitution audit: 1,146 examples each, no failures.
- Ruby 2.6.10: 1,145 examples, no failures, four existing oracle skips.
- Lint: all 50 implementation, harness, and affected spec files pass.
- All 100 standard benchmark combinations remain supported, with unchanged
  median SecondPass allocation counts. The plain-pattern fast path still
  allocates no intermediate objects.
- The focused matrix checks 1,260 body/bound/continuation variations against
  Ruby, with first matches, global scans, and complete capture arrays. Additional
  tests cover all three targets, nested captured loops, case-insensitive values,
  Unicode offsets, and the unchanged fast path.
- The existing capture grammar remains at 4,194 passes / 1,488 unsupported
  combinations for seed 1729, and 4,188 / 1,494 for seed 2718, without mismatches,
  errors, or timeouts. That grammar does not include the newly handled inner-loop
  shapes; its unchanged counts are regression evidence, not new-coverage totals.

The compiler is now 2,850 lines. This closes a specific ordering gap and can
shorten generated output, but does not meet the whole-implementation conciseness
goal or resolve the previously measured long-failure timeouts. Production still
uses the original pipeline.

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_empty_loop_order_spec.rb
bundle exec rspec --require ./spec/support/second_pass_compiler.rb
```

## Fifteenth milestone: forward assertion and atomic loop scopes

`SimplifyLoops` now traverses positive and negative lookaheads and atomic groups.
It keeps each boundary intact and does not use an outside continuation to remove
internal alternatives. Capture-free, unconditional empty-first loops retain the
normalization from milestone 14, including their finite maximum counts. This
supports patterns such as `(?=((?:|a)*a))\1b` and `(?>(?:|a)*a+)b` while preserving
assertion commitment and capture values.

`LowerNullableLoops` also enters these forward scopes when the repeated
capture's reads stay within the rewritten region. A completed forward assertion
commits its internal match, so the nullable-loop stopping probe can use that
internal continuation independently of the outside tail. The atomic adapter's
synthetic lookahead capture has the same boundary. Lazy scalar loops keep their
backtrackable consuming alternatives. The scope matrix checks greedy and lazy
stars/pluses, three body shapes, three continuations, and nested assertions.

The boundary review exposed an existing incorrect conversion outside assertions:
`((a*?)*\2)b` could return only `b` on `ab`. Its stopping probe saw the local
backreference succeed with empty, but could not see the failing `b` beyond the
enclosing capture. Greedy lowering now requires a complete continuation or proof
that the unseen tail always succeeds. Incomplete cases raise `Unsupported`
before changing the input tree; the lazy counterpart remains supported because
it can still retry consuming alternatives after the outside tail fails.

These rules do not admit escaping repeated values, lookbehind traversal,
reference-dependent empty bodies, or general capture histories. Production
continues to use the original pipeline.

Validation:

- Normal suite and compiler substitution audit: 1,162 examples each, no failures.
- Ruby 2.6.10: 1,161 examples, no failures, four existing oracle skips.
- Lint: all 51 implementation, harness, and affected spec files pass.
- Focused coverage includes 180 capture-free scope variations and 144 closed
  nullable-capture scope variations, comparing first and global matches against
  Ruby. The capture-free cases also compare complete capture arrays where no
  synthetic atomic capture is needed. Additional cases check commitment after
  outside failure and rejection without input-tree mutation.
- Both unchanged 1,894-pattern capture sweeps retain their previous results:
  4,194 passes / 1,488 unsupported combinations for seed 1729, and 4,188 / 1,494
  for seed 2718. Neither reports mismatches, errors, timeouts, or changes in
  support. The new scope shapes are covered by the focused matrices above.
- All 100 standard benchmark combinations remain supported with unchanged
  generated-source sizes. Skipping capture-free subtrees in nullable-capture
  lowering reduces median allocations in 18 combinations; the other 82 are
  unchanged. For example, constant loop state falls from 5,175 to 5,099 and
  overlapping lazy branches from 5,185 to 5,085. Plain patterns still allocate
  no intermediate objects. These are allocation results, not runtime speedups.

The compiler is now 2,874 lines. General continuation handling, observable
capture layout, the implementation-size goal, and previously measured failing
input timeouts remain open.

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_scope_loops_spec.rb
```

## Sixteenth milestone: composite selection and nullable choices

Split capture values can now participate in duplicate-name selection and capture
histories. Selection happens over the complete original value before its reads
are decomposed into segments. Histories choose the newest participating value;
duplicate names choose the first matching value and commit even if its following
continuation fails. Both rules use the existing conditional/choice IR, without
another value representation or a new pipeline pass.

The broader checks exposed two additional gaps:

- The converter discarded older subexpression-call occurrences when the
  original capture could be empty. It now retains these histories, allowing an
  absent later capture to fall back while a participating empty value commits.
  This also corrects production conversion of
  `\A(?<x>a*(?<y>b*)?)\g<x>?\k<x>\k<y>?\z` on `baab`.
- JavaScript's greedy optional can skip an empty capture update and instead
  consume input. For instance, `(b*?)?` on `b` must prefer an empty capture.
  Unreferenced nullable captures now use an explicit ordered choice. Referenced
  captures stay in optional form for the existing continuation-aware lowering;
  eagerly expanding them duplicated work and increased allocations. Analysis
  identifies candidates using complete reference counts before enabling the
  simplification pass.

Nullable-choice lowering now traverses forward assertions and atomic groups
when the copied region's capture reads remain internal. It retains the atomic
adapter's capture/reference boundary. Capture-free subtrees are skipped because
they cannot require capture-participation lowering. The full run also caught and
fixed a missing string guard in the end-of-input classification helper.

The differential runner now has `scopes` and `composites` suites. The former
enumerates 936 patterns, including closed nullable choices in assertions; the
latter enumerates 360 patterns with duplicate names and subexpression calls.
Both support first-match and global comparisons and all three targets. They
extend the existing capture grammar rather than replacing it.

Ruby 2.6's known duplicate-name bug affects six new oracle comparisons. These
are explicitly skipped on pre-3.1.3 Ruby, alongside the four existing skips.
Separate fixed expectations, also checked against modern Ruby, exercise those
six cases on every supported runtime without adopting the old engine's bugs.

Validation on the final implementation:

- Normal suite and compiler substitution audit: 1,181 examples each, no failures.
- Ruby 2.6.10: 1,180 examples, no failures, ten documented oracle skips.
- Lint: all 53 implementation, harness, and affected spec files pass.
- All 2,808 scope/target combinations pass both first-match and global checks.
- All 1,080 composite/target combinations pass first-match checks and global
  checks; global checks also pass with seed 2718.
- The original 1,894-pattern capture grammar remains at 4,194 passing / 1,488
  unsupported combinations for seed 1729 and 4,188 / 1,494 for seed 2718, with
  no mismatches, errors, or timeouts. General loop coverage remains incomplete.
- All 100 standard benchmark combinations remain supported and their generated
  source sizes are unchanged. Compared with milestone 15, median SecondPass
  allocations decrease in 88 combinations and stay unchanged in 12. Examples:
  required reference 224 to 216, nullable capture 652 to 641, bounded empty
  iterations 12,464 to 11,093, and overlapping lazy branches 5,085 to 4,985.
  Plain patterns still allocate no intermediate objects. These measurements
  describe the current workspace, including the intervening local cleanups;
  they do not establish a runtime speedup or resolve long-failure timeouts.

The compiler currently contains 2,969 lines. Whole-implementation conciseness,
general retained-value histories, and final production migration remain open.

```sh
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --implementation compiler --suite scopes --patterns 10000 --global
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --implementation compiler --suite composites --patterns 10000 --global
```

## Seventeenth milestone: ordered lazy loops and continuation filtering

Lazy scalar loops now support regular bodies that try all consuming paths
before their empty path, including `a*`, `a*b*`, and `a|`. Structural analysis
distinguishes these from bodies that interleave empty and consuming choices.
The native lazy prefix still visits consuming paths in order. An existence
probe defers its empty ending whenever a consuming continuation can succeed;
the probe is finite because each further iteration must consume input. As with
greedy stopping probes, this requires a complete continuation. Incomplete
continuations across capture boundaries remain unsupported.

A scalar nullable loop with an unbounded minimum above one can now have a
finite required prefix expanded using the existing empty-update checks. A
stable empty update bypasses the remaining prefix and unbounded tail, even
before the required minimum. This enables additional participation-condition
cases; arbitrary retained-value continuations still need further lowering.
Finite empty-first scalar loops are also expanded when no capture values are
read, since empty-update order can still affect the matched text.

The new checks exposed `(a*?b*?){2,}(?(1)b|a)` incorrectly returning `bb` on `bb`
after specialization removed its last value read. The compiler now rejects
unhandled empty-first ordering even for unobserved captures. Bodies proved to
match only empty are exempt, preserving the existing native fast path.

`TailFilter` rejects impossible continuations before expensive partition
searches in lazy nullable loops and disjoint lazy capture runs. Its lookahead
accepts a superset of the continuation's language: nullable values may be any
string, nonempty regular capture values may be any string in their original
language, conditional branches are unioned, and assertions are omitted. It
preserves regular grouping, adds no captures, and cannot select a different
successful path. The original lowering still verifies the actual match.

Final emission now removes passive wrappers around children that already have
a quantifiable group boundary. It retains wrappers around repeated children
and assertions, avoiding overwritten quantifiers or invalid Unicode-mode
syntax. The default representation adapter remains structurally faithful;
compaction is enabled only by the compiler pipeline.

The standalone stress benchmark now includes the lazy nullable failures from
milestone 13 as well as consuming-first bodies. All 18 ES2018 stress cases
(six families at lengths 16, 64, and 256) complete without the one-second
timeout. The previously failing scalar and lazy-run families take less than
one millisecond per input at length 256 in this run. This is a measured
improvement for these failure shapes, not a general backtracking bound.

Compared with milestone 16, all 100 standard benchmark combinations remain
supported with identical capture counts. Generated source shrinks in 24
combinations and stays unchanged in 76. Median allocations decrease in 22,
stay unchanged in 69, and increase in nine (by 1–13 objects). For example, the
multiple-lazy-capture output shrinks from 1,875 to 1,806 bytes while its
allocation count rises from 18,204 to 18,217. The compiler is now 3,098 lines;
the overall implementation-size goal remains open.

The normal suite and compiler substitution audit each pass 1,192 examples.
Ruby 2.6 passes with 1,191 examples and ten known Ruby-oracle skips. The original
1,894-pattern capture grammar has 4,314 passing case/target combinations and
1,368 unsupported combinations for seed 1729; seed 2718 has 4,305 passing and
1,377 unsupported. These add 120 and 117 supported combinations respectively,
with no previously supported case lost and no mismatches or runtime errors.
The global scope and composite suites pass all 2,808 and 1,080 combinations.

```sh
bundle exec rspec spec/lib/js_regex/second_pass/compiler_lazy_nullable_loops_spec.rb
bundle exec ruby -Ilib benchmark/second_pass.rb --implementation compiler --stress --target ES2018 --iterations 1 --samples 1
```

## Eighteenth milestone: nested captures with identical updates

Nullable unbounded loops now recognize chains of nested captures that cover
exactly the same iteration, such as `((a*?b*?))*?`. These captures always update
together. The scalar loop proof therefore applies to the whole chain: consuming
iterations bind every capture to the consumed value, and the explicit empty
ending updates every capture to empty. Participation checks specialize together,
while separate emitted occurrences preserve reference bindings in copied probes.

This supports greedy and ordered lazy loops with multiple value reads, negative
assertions, and participation conditions. Passive single-child groups may occur
between captures. Optional captures, repetitions, extra consumed text, or a
skipping alternative break the chain and retain their separate history rules.
The change does not claim to preserve the generated capture-array layout where
the scalar lowering already adds synthetic groups; existing layout-preserving
run simplifications remain covered separately.

The new deterministic `aliases` grammar contains 576 patterns with two or three
nested captures, eight nullable bodies, four loop quantifiers, and six
continuations. Both seeds 1729 and 2718 pass all 1,728 case/target combinations;
seed 1729 checks global matches and seed 2718 checks first matches. Focused specs
also compare both match modes for all 240 two-capture variants on all targets,
plus named references, case folding, astral input, and assertion scopes.

All 100 standard benchmark combinations retain identical generated source sizes
and capture counts. Compared with milestone 17, median allocations are unchanged
in 97 combinations and rise by four objects in three. The compiler is 3,127
lines; the new support does not close the overall size or performance goals.

The normal suite and compiler substitution audit each pass 1,195 examples.
The focused nullable-loop suites on Ruby 2.6 have 59 examples, no failures, and
one known nested-quantifier oracle skip. Lint passes for all 54 checked files.
The original capture grammar gains 36 supported case/target combinations per
seed: seed 1729 now has 4,350 passing and 1,332 unsupported combinations, while
seed 2718 has 4,341 passing and 1,341 unsupported. Neither seed loses a previously
supported case or reports a mismatch, JavaScript error, or timeout.
The global scope and composite suites also remain green at 2,808 and 1,080
case/target combinations respectively.

```sh
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --implementation compiler --suite aliases --patterns 10000 --seed 1729 --global
```

## Nineteenth milestone: complete continuations and forward scopes

Passive groups and choices now carry the continuation needed by an unbounded
nullable tail, even when capture participation is already certain. This closes
the gap left by expanding required prefixes: their stopping branches retain
their original order, and the unbounded tail can test the actual suffix.
Higher minimums now support scalar value reads as well as participation tests.
Nested captures covering the same iteration also use this proof for finite
bounds and required prefixes. Their structural recognition is shared with
the existing run simplification rather than duplicated between passes.

Whole-iteration nullable values can also be lowered when additional nested
regular captures are never read. The outer value determines the continuation's
observable state. Captures with independent value reads, assertions in the
body, and mixed lazy/greedy empty-path orders retain their existing restrictions.
The consuming prefix keeps the nested capture slots; this transformation does
not promise a stable Ruby capture-array layout. Empty-last recognition also
accepts redundant trailing empty alternatives introduced by optional lowering.

An independent suffix may now be checked before an enclosing capture closes,
letting the loop's stopping probe see a failure beyond that boundary. The
suffix still consumes outside the capture, preserving its value. This rule
requires a capture-free suffix that does not read the enclosing capture, and
all reads of nested captures must remain inside that capture. It neither moves
consumption across an assertion nor lets an outside failure retry a committed
assertion. The finite-state and disjoint lazy-run passes now also traverse
forward assertion and atomic scopes, with their existing closure checks.

The nullable-choice pass skips trees whose referenced nullable captures are
already mandatory and which contain no unbounded capture loop. Continuation
filters now cover greedy nullable loops and guarded capture boundaries as well
as lazy loops. Required prefixes receive their filter before expansion: placing
it only at the unbounded tail left expensive partition searches in the prefix.

All 27 stress combinations (nine families at lengths 16, 64, and 256) complete
within the one-second limit. The new required-prefix family initially timed out
at lengths 64 and 256; moving its filter ahead of the prefix brings the length
256 failure to about 0.24 ms per input in this run. These are specific failure
shapes, not a general bound on backtracking.

All 100 standard benchmark combinations remain supported with unchanged
capture counts. Compared with milestone 18, source size is unchanged in 97
and increases by 17 bytes in three for the added greedy continuation filter.
Median allocations decrease in 76, stay unchanged in three, and increase in
21. The required-reference case drops from 216 to 206 allocations; bounded
growth at 16 drops from 8,587 to 8,273. Empty-iteration backtracking adds 208
allocations for its new filter and checks. The compiler is 3,188 lines, so the
overall conciseness and performance gates remain open.

The normal suite and compiler audit each pass 1,199 examples. The full Ruby 2.6
run has 1,198 examples, no failures, and ten known oracle skips. The extended
alias grammar has 1,008 patterns: both seeds pass all 3,024 case/target
combinations, with global matches for seed 1729 and first matches for seed 2718.
The expanded scope grammar passes all 2,856 global combinations; the composite
grammar remains green at 1,080 global combinations. Lint passes for the 48
compiler, compiler-spec, benchmark, and support files checked here.

The differential harness now separates compiler timeouts from Ruby-oracle
timeouts, uses Ruby's native regex deadline when available, and caches oracle
results across targets and implementations. Newly supported nested nullable
patterns exposed extremely slow Ruby matching: one diagnostic took about 251
seconds in Ruby while JavaScript returned the same first-match results in
about 4 ms. These failures remain reported; they are not counted as passes or
silently removed. `--max-input-length` explicitly selects a shorter corpus for
an additional comparison and records that limit in the report.

At a maximum input length of seven, the capture grammar has 4,770 passing,
909 unsupported, and three oracle-timeout combinations for seed 1729 (global
matches); seed 2718 has 4,764 passing, 915 unsupported, and three oracle-timeout
combinations (first matches). Neither reports a mismatch, JavaScript error,
or compiler timeout. These shorter-corpus figures are not equivalent to the
earlier unrestricted-input runs.

The final unrestricted seed-1729 run has 4,731 passing combinations, 909
unsupported, and 42 Ruby-oracle timeouts. It reports no semantic mismatches,
JavaScript errors, or compiler timeouts. Relative to milestone 18, 381 formerly
unsupported combinations now pass and another 42 reach the oracle timeout;
every previously passing combination still passes.

A direct migration comparison uses the same 1,894 patterns, ES2018 target,
seed 1729, first-match mode, and maximum input length of five for both passes:

| Legacy result | Compiler result | Patterns |
| --- | --- | ---: |
| Pass | Pass | 1,457 |
| Mismatch | Pass | 134 |
| Pass | Unsupported | 151 |
| Mismatch | Unsupported | 152 |

The compiler reports no mismatches in that comparison, but the 151 patterns
accepted by the legacy pass with correct sampled results are a concrete
migration blocker. Production remains on the legacy implementation. Removing
its step-isolation tests and `STEPS`-dependent cache is deferred with that switch;
those tests still exercise live production code. Existing stable-layout tests
remain alongside the broader match-text/offset tests, and the documented native
capture-array and keep-mark limitations remain unchanged.

```sh
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --implementation both --suite captures --patterns 10000 --target ES2018 --seed 1729 --max-input-length 5
bundle exec ruby -Ilib benchmark/second_pass_differential.rb --implementation compiler --suite aliases --patterns 10000 --seed 1729 --global
bundle exec ruby -Ilib benchmark/second_pass.rb --implementation compiler --stress --target ES2018 --iterations 1 --samples 1
```

## Native RegExp contract decision

General keep-mark search semantics cannot be a completion gate while also
requiring only native JavaScript RegExp source and flags. This is separate from
the compiler's remaining implementable capture-history gaps.

For `/a\Ka/` on `aaa`, the current lookbehind conversion is `(?<=a)a`:

| Search start | Ruby match start | Converted JS match start |
| --- | --- | --- |
| 0 | 1 | 1 |
| 1 | 2 | 1 |
| 2 | No match | 2 |

Ruby consumes its prefix at or after the requested search start. A lookbehind
can inspect input before JavaScript's `lastIndex`. During an ordinary native
RegExp search, a pattern attempt at index 1 cannot distinguish a search begun at
0 from one begun at 1. Ruby requires different outcomes for those two attempts.
Changing the lookbehind alone cannot recover the missing search-origin state.
Global scanning exposes the same issue: Ruby returns one match, whereas the
current conversion returns two by reusing the first match's consumed prefix.

Keeping the existing `source`/`options`, `to_h`, and `to_s` contract therefore
requires explicit compatibility limits; a JavaScript execution wrapper could
instead retain search-origin state and adjust returned match boundaries.
The README now documents the existing limitation. No execution wrapper or
change in conversion warning policy has been introduced. The user chose to
retain native output and document unavoidable compatibility limits. General
keep-mark scanning equivalence is therefore not a prerequisite for migration;
the remaining capture-history and performance gates still apply.

## Remaining work before switching production

1. Close the remaining unbounded-loop gaps: general empty-update histories,
   empty-first alternatives retaining variable values, nullable repetitions
   outside the greedy-star, scalar-participation, and ordered lazy scalar rules
   (including their identical-update capture chains and required prefixes),
   and overlapping variable values. Self-referential
   loops remain a separate problem. Keep applicable subsets explicit; finite
   participation bits cannot represent arbitrary values.
   Capture-free inner repetitions now preserve unconditional empty-first order
   in regular bodies, including inside forward assertions and atomic groups;
   context-dependent empty paths and unhandled scopes remain.
2. Close remaining scope gaps across assertion/atomic boundaries,
   especially escaping repeated values and capture-dependent outside continuations,
   and unrecognized opaque capture semantics. Composite values now support
   duplicate-name/history selection, but their enclosing repeated regions still
   need the general history proofs. Check references escaping copied regions explicitly.
   Preserve the documented native-output limits for keep marks rather than
   introducing an execution wrapper. Unequal offsets are supported for proven
   literal alternatives; broader prefix and global behavior remains limited.
   Ordinary Ruby backreferences inside lookbehind are rejected by Ruby itself
   and are not a reason to relax the compiler's ordering checks.
3. Review observable capture layout beyond the cases preserved by
   `SimplifyLoops`. Migrate the legacy step-isolation specs when removing the old
   pipeline, retaining their behavioral coverage. The two integration snapshots
   and audit adapter have been migrated; match and capture-array differences
   must remain visible.
4. Consolidate the implementation toward the requested conciseness and finish
   the performance review. Simpler cases still allocate more than the old
   pipeline and bounded empty loops allocate more. The measured lazy-loop
   failure families now pass through length 256; broader adversarial runtime
   checks remain necessary. The expanded nine-family stress matrix now passes
   through length 256. Extend the generated grammar and runtime matrix;
   benchmark coverage alone does not justify rollout.
5. Switch the public entry point after those gates, migrate the `STEPS`-coupled
   specs/cache, remove the old implementation, and run the complete suite again.
   The migration comparison above currently identifies 151 patterns whose
   sampled legacy behavior passes but which the compiler rejects.
   Generated source may change where it is not a syntax guarantee.

Do not introduce expansion limits or silently drop unsupported transformations
as part of this rewrite. Those would change conversion policy. Prefer native
quantifiers when proven equivalent and local specialization when it preserves
ordered backtracking; retain an isolated permutation strategy where necessary.
