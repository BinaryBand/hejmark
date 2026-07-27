# The engine protocol

What an engine outside this process must implement, and what it may assume. The foundation docs stop at the language; the payload and this protocol are host concerns, so they live here.

The goal is an engine that is **interchangeable**: it receives data, returns data, and shares no code with the compiler. That is achievable except at one point, and this document is mostly about being precise where the exception is.

## What crosses

Only JSON, in the shapes `hejmark/core/ir/wire.py` and `hejmark/core/ir/codec.py` define, explained in [shapes/](shapes/README.md). Faces and template text are code-point arrays; nothing else needs decoding.

Transport is deliberately unspecified -- stdio, a socket, FFI, in-process callbacks all conform. What follows constrains *behaviour*, not mechanism. One transport is nevertheless implemented and tested, and [the wire](#the-wire) describes it; an engine that speaks it needs no adapter written for it.

## Three verbs

| Verb | Direction | When |
| --- | --- | --- |
| `run(program, document) -> document` | host -> engine | execution |
| `zero(universe) -> face \| null` | compiler -> engine | compilation |
| `digits(universe) -> [face]` | compiler -> engine | compilation |
| `resolve(slot, faces) -> universe` | engine -> compiler | execution |

`run` is the whole job: statements in order, document threaded through, sentinel faces stripped at the end.

`zero` and `digits` are the compiler's only questions about a denotation, and they exist because two surface constructs are *defined* by a bounded read of one -- `@0` reads a universe's zero entry, and a value cut reads the head radix's digits. `zero` returns the canonical face of the first entry, or null for an empty universe. `digits` returns the canonical face of every entry, in value order.

There is no streaming or cursor verb, and none is needed: these two are the only consumers, and each consumes a fixed amount.

`resolve` is the exception to interchangeability. A back-referencing factor cannot be lowered ahead of a binding, so it crosses as a slot and the engine asks the compiler to expand it once its reads are bound. Faces in, a floor universe out -- pure data both ways, but it is a call *back*.

## Requirements

**1. The protocol must be re-entrant.** `resolve` re-enters expansion, which asks `zero`/`digits` again. On `static/examples/demos/bubble-sort.hmk` each `resolve` triggers about seven such calls *inside* it, while the engine is still waiting for its answer. A transport that cannot service an inbound call while an outbound one is outstanding will deadlock. This is correctness, not throughput.

**2. Memoize `resolve` on the projected read faces.** Two attempts that agree on the faces its `needs` project to have the same answer. With the memo, traffic tracks the number of *distinct bindings a document presents* rather than its length -- measured at 4/6/6/10 calls for 4/8/16/32 items on the sort demo, where the ten distinct digit faces are the ceiling. Without it, every match attempt is a round trip.

**3. `digits` on an unbounded universe does not return.** In-process this is a hang, deliberately: the floor answers or diverges, it never guesses. An out-of-process engine may reproduce the hang or refuse, but must not invent a truncated radix.

**4. A slot-free program needs no back channel at all.** If your engine only ever receives programs with no `slot` factor, `resolve` is dead and the protocol is one-way. The corpus marks these with `requires`.

## The wire

The implemented transport: **one JSON object per line, in both directions, over a pair of streams.** `hejmark/adapters/channel.py` is it, and `hejmark serve-engine` runs this package's engine behind it. An engine speaking this needs nothing written on the host side -- `hejmark/adapters/remote.py` already talks to it.

Three message shapes, and no others:

```json
{"id": 1, "verb": "run", "params": {...}}
{"id": 1, "ok": {...}}
{"id": 1, "error": {"category": "scope", "message": "..."}}
```

Ids pair a call with its answer and are per-direction: each end numbers its own calls, so both may use `1` at once and neither is confused, because a response only ever comes back down the stream the request went up. Every message is flushed. Anything else on the line -- a truncated object, an answer to a call nobody made -- ends the conversation rather than being repaired.

| Verb | `params` | `ok` |
| --- | --- | --- |
| `run` | `{"program", "document"}` | `{"document"}` |
| `zero` | `{"universe"}` | `{"face"}`, null if empty |
| `digits` | `{"universe"}` | `{"faces"}` |
| `resolve` | `{"slot", "faces"}` | `{"universe"}` |

`program` is the `hejmark-program` object; `universe` is the codec's; **`document`, `face` and `faces` are code-point arrays**, same rule as everything else that carries a spelling. That is not free -- a document costs several times its length -- but a document is exactly where a lone surrogate would turn up, and a transport that mangles one is worse than a slow one.

`error.category` is one of the three below and nothing else; a category the reader does not know stays unread rather than being guessed at.

The requirement re-entrancy places on all this is small in code and non-negotiable in effect: **both ends run the same loop**, and waiting for an answer differs from serving only in when it stops. An end reads messages, answers requests as they arrive, and returns when the answer it is waiting for shows up. Nesting is that loop entered again from inside a dispatch, which is what `digits`-inside-`resolve`-inside-`run` actually is.

## Division of labour

The split is chosen so no logic exists on both sides.

| The engine owns | The host/compiler owns |
| --- | --- |
| Denotation: membership, entries, the collision rule | Parsing, name resolution, L1.5 expansion |
| Matching: leftmost-greedy, no zero-width | Sentinel allocation, and resolving `{{@name}}` to a face |
| Capture binding: `$`, `$0`, `$k` | Lowering to the payload, and `resolve` |
| Stripping sentinel faces on exit | The L2 ingest refusal, before `run` is called |

Two consequences worth stating, because they are easy to get backwards:

- **Sentinel names never cross.** The compiler allocated them, so it substitutes faces while lowering. A program carries faces to strip and nothing else.
- **The captures are not the matcher's pieces.** Where a spelling splits more than one way, the floor binds it to the least `<value, face>` address and `$0`/`$k` read *that* split. See [shapes/product.md](shapes/product.md).

## Errors

Three categories, named not messaged -- messages are deliberately unpinned.

| Category | Means |
| --- | --- |
| `payload` | The JSON did not decode. Refuse; never repair or guess |
| `scope` | A capture read nothing anchors, or a factor read past the query |
| `sentinel` | A document arrived already spelling a noncharacter (the L2 guard) |

`hejmark/core/ir/errors.py` holds that table as `CATEGORIES`, so the name and the exception it becomes are stated once. A refusal that crosses the wire arrives on the far side as the exception it was raised as -- a refused program raises the same thing whether the engine ran here or elsewhere.

## The host side

`hejmark/core/ir/ports.py` declares this contract as a Python `Protocol`, and
`hejmark/core/driver.py` reaches an engine only through it -- carried in an
`Adapters(to_ast, engine)` bundle beside the parser. `hejmark/core/engine/service.py`
is the in-process implementation and the reference the corpus is generated from.

An out-of-process engine is therefore an *adapter*: something under
`hejmark/adapters/` that satisfies the same two verbs by talking to another
process. Nothing under `core/` changes to accommodate it, and
`hejmark/adapters/remote.py` is that adapter for the wire above -- it is an
`Engine`, so `Adapters(to_ast, Remote(...))` runs a whole script against a
process that has never seen a `.hmk` file.

`zero` and `digits` appear on that Protocol as the single lazy `canonical_faces`,
because in-process laziness expresses both: taking one face is `zero`, taking
all of them is `digits`. Over a wire they are two bounded calls, and `Remote`
is where the translation happens: taking one face sends `zero` and stops there,
which is what keeps `@0` on an unbounded universe from asking for a radix that
does not end.

## Conformance

`static/conformance/` is the executable form of this document: cases carrying a payload and the answer any engine must produce. Making it pass is the definition of a working engine. Start there, not here.

**Read the corpus in your own language, not over this protocol.** The verbs above are `run`, `zero` and `digits`; there is none for entries or membership, so the corpus's `denote` and `match` suites cannot be asked over a pipe at all. Running scripts and comparing documents exercises denotation only where those scripts happen to reach. `rust/tests/conformance.rs` is the worked example of doing it properly: it loads the JSON, decodes the payloads and drives all four suites natively.

`tests/integration/test_transport.py` then checks the complementary half -- that the engine speaks *this* document -- by running the corpus over a real pipe. Point `HEJMARK_ENGINE` at your binary and it is that check for your engine.

## A second engine exists

`rust/` is one. It has no parser and no compiler: it decodes `hejmark/core/ir/`'s payload, denotes it, and answers the verbs above over stdio. Reading it beside `hejmark/core/engine/` is the fastest way to see what this document actually asks for -- the modules are a function-for-function port, and each names its Python counterpart in its header.

Two things it discovered, worth knowing before writing a third:

- **A spelling is a sequence of code points, not a string in your language's string type.** L1's spelling order is shortlex over the whole code space with surrogates unspecialised, so `D800` is an ordinary spelling with an ordinary successor. Rust's `char` cannot hold one; the engine uses `Vec<u32>` throughout. This is the same reason the wire carries code-point arrays.
- **The arena a payload decodes into has to keep growing.** `resolve` hands back a floor universe that did not exist when the program arrived, and it must land where the denotation is already reading.
