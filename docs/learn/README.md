# Learning Hejmark

These are teaching notes, not the specification. The normative specs live in `docs/foundation/` (`L1.md`, `L1_5.md`, `L2.md`, `L3.md`, indexed by `ROADMAP.md`) and in `docs/protocol.md`, and they are terse on purpose -- every sentence there is load-bearing. This folder is the opposite: it is slow, it repeats itself, it tells stories, and it is allowed to be a little imprecise in service of getting a picture into your head. When the two disagree, the spec wins; come back here to rebuild your intuition, then go read the real thing again.

A naming note before you start, because the specs will otherwise trip you: the project and its package are **Hejmark** (`pyproject.toml`'s `name`, the `hejmark` CLI, this repository), but the *language itself* -- the specs, the grammar, the error classes (`HimarkScopeError`, `HimarkUnsettledError`, ...) -- still carries its older name, **Himark**. You will see both. They mean the same thing; nothing in this curriculum makes anything of the difference beyond this paragraph.

In a hurry, or just want it all in one sitting? [`single-page.md`](single-page.md) distills all eleven lessons below into one document -- same facts, no per-lesson recaps or repeated exercises, denser but faster to read start to finish.

## Who this is for

An ambitious junior programmer who is comfortable writing code but has never had to think about ordinals, well-orders, or machine-checked proofs, and who has opened `docs/foundation/L1.md` once, felt the ground tilt, and closed it again. That reaction is correct. The document is dense because the ideas are genuinely subtle, not because it is trying to show off. The goal of these lessons is to get you to the point where that density reads as *economy* rather than *noise* -- where you can look at a single row of a north-star table and unpack the whole paragraph it compresses, and where you can point at a Python module or a Rust one and say what layer it belongs to and why.

## The path

Three tracks, meant to be read in order within a track, but the tracks themselves can be read in whichever order matches what you are trying to understand.

**Track A -- the language.** What Hejmark denotes, and what a script written in it means. This is `docs/foundation/`, retold.

1. [The universe: what Hejmark is about](01-the-universe.md) -- the single object the whole language is built on.
2. [The five constructors](02-the-five-constructors.md) -- the only five ways to build a universe.
3. [The theorems: what the object forces](03-the-theorems.md) -- positional value, canonical numerals, transfinitude, fixpoints, compression.
4. [The surface syntax](04-the-surface-syntax.md) -- names, definitions, registers, and the `=>`/`<=>` statements that use a universe against text. This is L1.5.
5. [The finite-execution contract](05-the-finite-execution-contract.md) -- why a total, infinite-capable denotation still runs to completion on your laptop. This is L2.
6. [The standard library](06-the-standard-library.md) -- `char`, `str`, `pad`, and the rest of L3, read as an admission test in practice.

**Track B -- the implementation.** How a `.hmk` file becomes a rewritten document, in two languages.

7. [The pipeline](07-the-pipeline.md) -- `hejmark/core/`'s stages, the compiler/engine/contract split, and why two of its modules are not allowed to import each other.
8. [The engine in another language](08-the-engine-in-another-language.md) -- `docs/protocol.md`, the conformance corpus, and `rust/`, a second engine that has never seen a parser.

**Track C -- reading the mechanization.** `static/lean/L1/` is a second, independently-checked source of truth for L1. Optional, and the deepest track -- come here once tracks A and B feel solid.

9. [Lean in a hurry](09-lean-in-a-hurry.md) -- a from-zero crash course in the proof assistant. No Hejmark in this one, just the tool.
10. [Reading the mechanization](10-reading-the-mechanization.md) -- a guided tour of `static/lean/L1/`: the membership axis, the order axis, and where they meet.
11. [The order-axis proofs, up close](11-the-order-axis-proofs.md) -- a line-by-line reading of the first three order-axis files, the best first proofs to actually understand.

## How to read a lesson

Do not read passively. Every lesson has small exercises marked with `:pencil:`. Do them on paper before reading the answer. The single biggest predictor of whether this material sticks is whether you tried to spell something out yourself and got it wrong first. The north-star table in `docs/foundation/L1.md` (and the north-star statements in `L1_5.md`) are your answer key: pick any row, cover the right-hand column, and try to predict what the expression denotes. When you are routinely right, you understand L1.

## A note on notation

Hejmark expressions are written in braces: `{a,b,c}`, `{a..z}`, `{cat}{dog}`, `{a, &{b}}`. Math is written in LaTeX-style notation: $\omega$ is the first infinite ordinal, $\varepsilon_0$ is a much larger one you will meet in lesson 3, $\omega^\omega$ sits between them. Lean code, when we show it, is transliterated to plain ASCII with a symbol legend (lesson 9), because these `.md` files are kept ASCII-only; the real `.lean` files use the pretty Unicode symbols and we always point you to them.
