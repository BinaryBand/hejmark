# The engine protocol

What an engine outside this process must implement, and what it may assume. The foundation docs stop at the language; the payload and this protocol are host concerns, so they live here.

The goal is an engine that is **interchangeable**: it receives data, returns data, and shares no code with the compiler. That is achievable except at one point, and this document is mostly about being precise where the exception is.

## What crosses

Only JSON, in the shapes `hejmark/core/ir/wire.py` and `hejmark/core/ir/codec.py` define, explained in [shapes/](shapes/README.md). Faces and template text are code-point arrays; nothing else needs decoding.

Transport is deliberately unspecified -- stdio, a socket, FFI, in-process callbacks all conform. What follows constrains *behaviour*, not mechanism.

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

## Conformance

`static/conformance/` is the executable form of this document: cases carrying a payload and the answer any engine must produce. Making it pass is the definition of a working engine. Start there, not here.
