# The conformance corpus

The language-neutral contract between hejmark engine implementations. Each `*.json` file is a suite of cases carrying a **lowered payload** -- floor JSON or a whole `Program` -- beside the answer any engine must produce for it. A host with an engine and no compiler can run the entire corpus without parsing a line of hejmark source; that is the point, and it is what makes the payload's sufficiency a checked claim rather than an intention.

The Python implementation is today's source of truth: expected answers are generated from it, then checked in and reviewed as ordinary diffs. Coverage is hand-picked for what a second implementation is most likely to get wrong.

- Runner and case inputs: `tests/integration/test_conformance.py`
- Regenerate: `HEJMARK_UPDATE_CONFORMANCE=1 uv run pytest tests/integration/test_conformance.py`
- Payload formats: `hejmark/core/ir/wire.py` (programs), `hejmark/core/ir/codec.py` (universes)

A stale corpus is a test failure, so a change in lowering surfaces as a corpus diff in review rather than as silent drift between implementations.

## File shape

```json
{ "format": "hejmark-conformance", "version": 1, "suite": "denote", "cases": [ ... ] }
```

Expected values are plain JSON strings. Payloads use the wire encoding, where faces and template text are **code-point arrays** (the lone-surrogate rule) -- so `"text": [99, 97, 116]` is `cat`. Do not conflate the two.

## Suites

### `denote.json` -- L1 denotation

The core: does a universe wear a spelling, and what are its entries in declaration order under the collision rule.

| Field | Meaning |
| --- | --- |
| `source` | The expression, for diagnostics. A top-level product is already wrapped in one brace pair so it denotes as one universe |
| `universe` | The floor payload to denote (`codec.py` shapes) |
| `limit` | `null` for a finite universe (assert *every* entry); an integer for an infinite one (assert that many, streamed lazily) |
| `entries` | Entries in order, each a list of faces, canonical face first |
| `contains` | Spelling -> whether some entry wears it |

Entries must be produced **lazily**: a case with a `limit` is infinite, and an implementation that materializes before truncating will not terminate.

### `match.json` -- scanning

| Field | Meaning |
| --- | --- |
| `query` | One floor payload per factor, in written order |
| `text` | The target |
| `match` | `null` when nothing matches, else the object below |

`match.span` is the whole hit; `match.parts` is one `{span, face}` per factor. `match.canonical` is `$0` and `match.factors` is `$1..$n`.

**These last two are not the parts.** The matcher's leftmost-greedy walk yields *a* witness split; where a spelling splits more than one way the floor binds it to the least `<value, face>` address, and the captures read *that* split. The corpus case `{a,ab}{c,bc}` on `"abc"` pins the difference: `parts` are `["ab", "c"]` while `factors` are `["a", "bc"]`. An implementation that reports the matcher's parts for `$k` passes every other case and fails this one.

The empty spelling is never matched: zero-width never hits.

### `run.json` -- whole programs

| Field | Meaning |
| --- | --- |
| `program` | The `Program` payload (`wire.py`) |
| `document` | The input document |
| `output` | The spliced document |
| `requires` | Capabilities the case needs; empty means standalone |

`requires: ["late-resolver"]` marks a program carrying a `LateSlot`. A back-referencing factor cannot be lowered ahead of a binding, so resolving one means calling back into the compiler that emitted the program -- the one thing a payload cannot carry. A standalone engine should **skip** these cases rather than fail them, and report them as skipped.

Sentinels are engine-private: allocated per script from the noncharacter block, matchable while the script runs, and stripped from the final document.

### `refuse.json` -- what must be declined

A refusal is a conformance requirement: an implementation that returns an answer here is wrong, not lenient.

| Field | Meaning |
| --- | --- |
| `case` | `"run"` (execute the program against the document) or `"payload"` (decode `payload`) |
| `stage` | Who owns the refusal: `ingest`, `engine`, or `decode` |
| `error` | `sentinel`, `scope`, or `payload` |

`stage: "ingest"` is the L2 boundary guard, not the engine's: a document arriving already spelling a sentinel is refused before execution. A host that does not implement L2 should skip those rather than treat them as engine cases. `error` names a category, not a message -- messages are deliberately unpinned.

## The two channels (for an out-of-process engine)

An engine that runs in another process does not merely consume payloads; two callbacks cross the boundary in opposite directions, and the corpus's `requires: ["late-resolver"]` marks where. Measured, not assumed:

- **`ToFaces`** -- the engine streams a floor node's canonical faces back to the *compiler*, which needs it for `@0` and value cuts. Rare at compile time (one of the 22 example scripts calls it at all, 9 calls); heavy during slot resolution.
- **`LateResolver`** -- the compiler expands a back-referencing factor for the *engine*, per distinct binding of the factors it reads.

Three properties any transport must respect:

1. **The channels nest, so the protocol must be re-entrant.** Resolving one slot re-enters expansion, which calls `ToFaces` again: on `demos/bubble-sort.hmk` each slot resolution triggers ~7 `ToFaces` calls *inside* it. A blocking request/response transport that cannot service an inbound call while awaiting an outbound one will deadlock. This is a correctness constraint, not a performance note.
1. **Traffic scales with distinct bindings, not with document size.** The same script over 4/8/16/32 items needs 4/6/6/10 resolver calls: sub-linear, and flattening, because a slot memoizes on the faces its reads project to, so only a *new* binding costs a round trip. Note what does the bounding -- the read factor here is `uni digits = {@d,&@d}`, an infinite universe, yet a document of single digits can only ever present ten distinct faces, and the 32-item run saturates at exactly those ten. The bound is the number of distinct bindings the document actually presents, which is a property of the data rather than of the universe's size or the document's length.
1. **Memoize on the engine side.** Every measured call was a first-time key (calls == distinct), which is the memo working. Dropping it turns each match attempt into a round trip.

## Adding a case

Add the input row to the table at the top of `tests/integration/test_conformance.py`, regenerate, and review the generated answer as carefully as you would hand-write it: regeneration will happily enshrine a bug. The corpus is only as good as the review of its diff.
