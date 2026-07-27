# The conformance corpus

The language-neutral contract between hejmark engine implementations. Each
`*.json` file is a suite of cases carrying a **lowered payload** -- floor JSON
or a whole `Program` -- beside the answer any engine must produce for it. A
host with an engine and no compiler can run the entire corpus without parsing a
line of hejmark source; that is the point, and it is what makes the payload's
sufficiency a checked claim rather than an intention.

The Python implementation is today's source of truth: expected answers are
generated from it, then checked in and reviewed as ordinary diffs. Coverage is
hand-picked for what a second implementation is most likely to get wrong.

- Runner and case inputs: `tests/integration/test_conformance.py`
- Regenerate: `HEJMARK_UPDATE_CONFORMANCE=1 uv run pytest tests/integration/test_conformance.py`
- Payload formats: `hejmark/core/ir/wire.py` (programs), `hejmark/core/ir/codec.py` (universes)

A stale corpus is a test failure, so a change in lowering surfaces as a corpus
diff in review rather than as silent drift between implementations.

## File shape

```json
{ "format": "hejmark-conformance", "version": 1, "suite": "denote", "cases": [ ... ] }
```

Expected values are plain JSON strings. Payloads use the wire encoding, where
faces and template text are **code-point arrays** (the lone-surrogate rule) --
so `"text": [99, 97, 116]` is `cat`. Do not conflate the two.

## Suites

### `denote.json` -- L1 denotation

The core: does a universe wear a spelling, and what are its entries in
declaration order under the collision rule.

| Field | Meaning |
| --- | --- |
| `source` | The expression, for diagnostics. A top-level product is already wrapped in one brace pair so it denotes as one universe |
| `universe` | The floor payload to denote (`codec.py` shapes) |
| `limit` | `null` for a finite universe (assert *every* entry); an integer for an infinite one (assert that many, streamed lazily) |
| `entries` | Entries in order, each a list of faces, canonical face first |
| `contains` | Spelling → whether some entry wears it |

Entries must be produced **lazily**: a case with a `limit` is infinite, and an
implementation that materializes before truncating will not terminate.

### `match.json` -- scanning

| Field | Meaning |
| --- | --- |
| `query` | One floor payload per factor, in written order |
| `text` | The target |
| `match` | `null` when nothing matches, else the object below |

`match.span` is the whole hit; `match.parts` is one `{span, face}` per factor.
`match.canonical` is `$0` and `match.factors` is `$1..$n`.

**These last two are not the parts.** The matcher's leftmost-greedy walk yields
*a* witness split; where a spelling splits more than one way the floor binds it
to the least `<value, face>` address, and the captures read *that* split. The
corpus case `{a,ab}{c,bc}` on `"abc"` pins the difference: `parts` are
`["ab", "c"]` while `factors` are `["a", "bc"]`. An implementation that reports
the matcher's parts for `$k` passes every other case and fails this one.

The empty spelling is never matched: zero-width never hits.

### `run.json` -- whole programs

| Field | Meaning |
| --- | --- |
| `program` | The `Program` payload (`wire.py`) |
| `document` | The input document |
| `output` | The spliced document |
| `requires` | Capabilities the case needs; empty means standalone |

`requires: ["late-resolver"]` marks a program carrying a `LateSlot`. A
back-referencing factor cannot be lowered ahead of a binding, so resolving one
means calling back into the compiler that emitted the program -- the one thing
a payload cannot carry. A standalone engine should **skip** these cases rather
than fail them, and report them as skipped.

Sentinels are engine-private: allocated per script from the noncharacter block,
matchable while the script runs, and stripped from the final document.

### `refuse.json` -- what must be declined

A refusal is a conformance requirement: an implementation that returns an
answer here is wrong, not lenient.

| Field | Meaning |
| --- | --- |
| `case` | `"run"` (execute the program against the document) or `"payload"` (decode `payload`) |
| `stage` | Who owns the refusal: `ingest`, `engine`, or `decode` |
| `error` | `sentinel`, `scope`, or `payload` |

`stage: "ingest"` is the L2 boundary guard, not the engine's: a document
arriving already spelling a sentinel is refused before execution. A host that
does not implement L2 should skip those rather than treat them as engine cases.
`error` names a category, not a message -- messages are deliberately unpinned.

## Adding a case

Add the input row to the table at the top of
`tests/integration/test_conformance.py`, regenerate, and review the generated
answer as carefully as you would hand-write it: regeneration will happily
enshrine a bug. The corpus is only as good as the review of its diff.
