# Lesson 8: The engine in another language

Lesson 7 ended on a promise: the compiler and the engine are separated by a hard import boundary specifically so the engine could someday be *replaced*, not just refactored. This lesson is about the part of that promise that is already real. `docs/protocol.md` specifies exactly what an engine outside this process must do; `rust/` is a whole second engine that satisfies it, has never seen a `.hmk` file, and shares no code with the Python compiler at all.

## The goal: an engine that is interchangeable

The stated goal is an engine that receives data, returns data, and shares no code with the compiler -- achievable everywhere except one seam, which this lesson spends most of its time on. Only JSON crosses, in shapes `hejmark/core/ir/wire.py` and `codec.py` define (the friendly write-up is `docs/shapes/`). Faces and template text cross as **code-point arrays**, never as native strings -- `cat` is `[99, 97, 116]` -- because a JSON string cannot hold a lone surrogate, and lesson 3's shortlex order runs over the *whole* code space with surrogates riding along unspecialised. A `String`-typed engine would silently disagree with Python the moment a window spanned that block.

Transport itself is deliberately unspecified -- stdio, a socket, FFI, all conform. One transport happens to be implemented and tested (below), and an engine speaking it needs no adapter written for it at all.

## Four verbs, one exception

| Verb | Direction | When |
| --- | --- | --- |
| `run(program, document) -> document` | host -> engine | execution |
| `zero(universe) -> face \| null` | compiler -> engine | compilation |
| `digits(universe) -> [face]` | compiler -> engine | compilation |
| `resolve(slot, faces) -> universe` | engine -> compiler | execution |

`run` is the whole job in one call: statements in order, document threaded through, sentinel faces stripped at the end (lesson 5's exit strip). `zero` and `digits` are lesson 7's `ToFaces` callback, now crossing an actual wire instead of a Python function call -- `zero` is `@0` (the first canonical face, or null on an empty universe); `digits` is a value cut's radix (every canonical face, in value order). There is deliberately no streaming or cursor verb for either, because these two calls are the *only* consumers and each one needs a fixed, bounded amount.

`resolve` is lesson 7's `LateResolver`, crossing the same wire in the opposite direction, and it is **the one exception to interchangeability**: a back-referencing factor cannot be lowered ahead of a binding, so it crosses as a numbered slot, and the engine has to ask the compiler to expand it once the read it needs is actually bound. Faces go in, a floor universe comes back -- pure data both ways, but it is a genuine call *back into the process that started the run.*

## Why this has to be re-entrant, and why that is not optional

Here is the requirement that makes this protocol harder to implement than it looks: **`resolve` re-enters expansion, which can call `zero`/`digits` again**, which might themselves need a further `resolve`. On the bubble-sort demo (lesson 4), each `resolve` triggers roughly seven such nested calls *while the engine's own `run` call is still outstanding and waiting for an answer.* A transport built as an ordinary client that sends a request and blocks for a reply cannot service an *inbound* call while its own outbound one is still open -- it will deadlock, every time, on any script that uses a back-reference at all.

The fix in this codebase is not a clever timeout or a background thread: it is that **both ends run the exact same loop.** `adapters/channel.py` (the Python side) and `rust/src/channel.rs` (the Rust side) are each one re-entrant read-dispatch-write loop, and "waiting for an answer" is simply that loop with a different stopping condition -- keep reading and answering whatever arrives until *your own* id comes back. Nesting is just that loop being entered again from inside a dispatch. This is why the codebase insists on one symmetric `Channel` class playing both roles rather than a client half and a server half: splitting it that way is exactly the shape that deadlocks.

Two more requirements worth knowing, because they are measured, not aspirational:

- **`resolve` must be memoized** on the faces its slot actually reads, because two attempts that agree on those faces have the same answer. With the memo, wire traffic tracks the number of *distinct bindings a document presents*, not the document's length -- measured at 4, 6, 6, and 10 calls for inputs of 4, 8, 16, and 32 items on the sort demo, where ten distinct digit faces is the actual ceiling. Without it, every single match attempt would be a fresh round trip.
- **`digits` on an unbounded universe does not return.** In-process this is a hang, and it is meant to be one: the floor answers or diverges, it never guesses (lesson 3's totality, all the way out to the wire). An out-of-process engine may hang or may refuse, but it must never *invent* a truncated radix just to have something to send back.

## The wire, concretely

The implemented transport is one JSON object per line, in both directions, over a pair of streams:

```json
{"id": 1, "verb": "run", "params": {...}}
{"id": 1, "ok": {...}}
{"id": 1, "error": {"category": "scope", "message": "..."}}
```

Ids are per-direction -- each end numbers its own outgoing calls, so both sides can use `1` at the same moment without confusion, because a reply only ever travels back down the stream its request went up. Every message is flushed immediately, and anything else appearing on the line -- a truncated object, a reply to an id nobody sent -- ends the conversation outright rather than being repaired or guessed at.

## Who owns what

The split is chosen so that no piece of logic exists on both sides at once:

| The engine owns | The host/compiler owns |
| --- | --- |
| Denotation: membership, entries, the collision rule | Parsing, name resolution, L1.5 expansion |
| Matching: leftmost-greedy, no zero-width | Sentinel allocation, resolving a sentinel's face for `{{@name}}` |
| Capture binding: `$`, `$0`, `$k` | Lowering to the wire payload, and `resolve` itself |
| Stripping sentinel faces on exit | The ingest refusal, before `run` is ever called |
| L2's *run-time* refusals: unsettled membership, the read and work budgets | L2's *rewrites*: reach and the value-cut collapse, already applied before the payload ships |

Two consequences of this split are easy to get backwards, so state them plainly: **sentinel names never cross the wire at all** -- the compiler allocated them, so it substitutes their faces while lowering, and a program only ever carries faces to strip, never a name. And **the captures are not the matcher's own pieces** -- where a spelling splits more than one way, the floor has already decided ownership by the least `<value, face>` address (lesson 3's collision rule), and `$0`/`$k` read *that* split, not whatever the matcher happened to try first.

## Errors, categorized for a wire

`docs/protocol.md` names five error categories, matching lesson 5's refusal table one-to-one but grouped for transport: `payload` (the JSON itself did not decode -- refuse, never repair), `scope` (a capture read nothing anchors, or a read past budget), `sentinel` (a document arrived already spelling a noncharacter), `unsettled` (absence in an unguarded closure), `budget` (a run spent past the host's work budget). The last two carry the same asymmetry lesson 5 flagged: `unsettled` is semantic -- an engine answering `false` there is simply wrong, and `static/conformance/denote.json` pins `contains` as `true`, `false`, or `"unsettled"` -- while `budget`'s existence is required but its size is each host's own choice.

## The conformance corpus: the contract made executable

`static/conformance/` is what makes all of the above checkable rather than aspirational: JSON cases, each carrying its lowered payload alongside the expected answer, so that an engine with *no compiler at all* can still run the whole thing. Two directions are verified -- the checked-in payloads decode and run correctly, and each suite is independently re-derived from source to prove the checked-in file is not stale.

Here is the detail that matters most if you ever write a third engine: **the protocol only has verbs for `run`, `zero`, and `digits` -- there is no verb for raw entries or membership.** So the corpus's `denote` and `match` suites (which ask exactly those questions) **cannot be asked over a wire at all.** Running scripts and diffing documents only exercises denotation wherever those particular scripts happen to reach. The corpus has to be read in your own engine's language, directly off the JSON, not through the protocol -- `rust/tests/conformance.rs` is the worked example, loading and decoding the payloads and driving all four suites natively. `tests/integration/test_transport.py` then checks the complementary half over an actual pipe, and `HEJMARK_ENGINE='<command>'` points it at any engine you like.

## `rust/`: a second engine, function-for-function

`rust/` has no parser and no compiler. It decodes the payload `hejmark/core/ir/` defines, denotes it, matches with it, executes it, and answers the three-and-a-half verbs above over stdio -- nothing more. Its modules are a deliberately close port of `hejmark/core/engine/`, close enough that each Rust file's header names its exact Python counterpart, because two independent implementations of the same semantics are only maintainable if a human can diff them by eye when the conformance corpus disagrees. Where a "tidier" Rust shape would have drifted from the Python original, the codebase keeps the Python shape on purpose.

Two facts about it are worth carrying, because both were genuine discoveries, not up-front design choices:

- **A spelling is `Rc<[u32]>`, never a `String`.** The same reason the wire carries code-point arrays: Rust's `char` cannot hold a lone surrogate, and L1's spelling order does not skip that block.
- **The arena grows while a run is in progress.** Resolving a late slot mints a floor universe that did not exist when the payload was first decoded, and it has to land in the very arena the denotation is already reading from -- so nodes are handed out as `Rc<Node>` behind an interior-mutable arena, rather than a structure that gets sealed once at load time.

`cargo test` -- reading `static/conformance/*.json` directly -- is the gate that actually constrains this engine, precisely because the wire cannot ask the `denote`/`match` questions. `tests/infrastructure/test_rust_engine.py` adds the second, complementary half: the corpus's `run` suite over a real pipe against the built binary, proving the engine is correct *and* that it actually speaks `docs/protocol.md`.

## What you should now be able to say

- An out-of-process engine needs to satisfy four verbs (`run`, `zero`, `digits`, `resolve`), and only `resolve` breaks strict interchangeability, because a back-reference cannot be lowered ahead of its binding.
- The protocol must be re-entrant -- `resolve` re-enters expansion, which can call `zero`/`digits` again, while the original `run` is still outstanding -- which is why both ends run one symmetric loop rather than split into a client and a server half.
- `resolve` is memoized on the faces it reads, so wire traffic scales with distinct bindings, not document length; `digits` on an unbounded universe must hang or refuse, never truncate.
- The engine owns denotation, matching, and capture binding; the host owns parsing, expansion, and sentinel allocation -- sentinel names and matcher internals never cross the wire.
- The conformance corpus is the executable form of the whole protocol, but its `denote`/`match` suites have no wire verb to ride on, so a real port (like `rust/`) has to read the corpus natively rather than only over the transport.
- `rust/` is a second, independently-checked engine: no parser, spellings as code-point arrays rather than `String`, and an arena that grows mid-run to hold universes minted by `resolve`.

That closes Track B. If you want to go deeper on *why* L1's theorems are true rather than just trusting the north-star table, Track C -- starting with lesson 9 -- is a from-zero tour of `static/lean/L1/`, the machine-checked proof of everything Track A asked you to take on faith.
