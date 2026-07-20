# Learning Himark

These are teaching notes, not the specification. The specification lives in `docs/foundation/` and it is terse on purpose -- every sentence there is load-bearing and the north-star tables are the ground truth. This folder is the opposite: it is slow, it repeats itself, it tells stories, and it is allowed to be a little imprecise in service of getting a picture into your head. When the two disagree, the foundation wins; come back here to rebuild your intuition, then go read the real thing again.

## Who this is for

An ambitious junior programmer who is comfortable writing code but has never had to think about ordinals, well-orders, or machine-checked proofs, and who has opened `docs/foundation/L1.md` once, felt the ground tilt, and closed it again. That reaction is correct. The document is dense because the ideas are genuinely subtle, not because it is trying to show off. The goal of these lessons is to get you to the point where that density reads as *economy* rather than *noise* -- where you can look at a single row of the north-star table and unpack the whole paragraph it compresses.

## The path

Read these in order. Each one assumes the ones before it.

1. [The universe: what Himark is about](01-the-universe.md) -- the single object the whole language is built on, and why it is a "pointed alphabet" rather than a set of strings. Start here even if you are impatient; nothing else makes sense without it.
1. [The six constructors](02-the-six-constructors.md) -- the only six ways to build a universe, why there are exactly six, and the one rule they all obey (they never say no).
1. [The theorems: what the object forces](03-the-theorems.md) -- positional value, transfinitude, fixpoints, and compression. These are not features somebody added; they are consequences nobody could avoid. This is the hardest math lesson and the most rewarding.
1. [Lean in a hurry](04-lean-in-a-hurry.md) -- a from-zero crash course in the proof assistant: propositions as types, tactics, well-founded recursion, order isomorphisms, and what "axiom-free" actually means. No Himark here, just the tool.
1. [Reading the mechanization](05-reading-the-mechanization.md) -- a guided tour of `static/lean/L1/`: which file proves what, the crucial split between the "membership axis" and the "order axis," and how the CI gates keep everyone honest.
1. [The order-axis proofs, up close](06-the-order-axis-proofs.md) -- a line-by-line reading of the first three order-axis files (`Order.lean`, `Positional.lean`, `Collision.lean`), which are the most self-contained and the best first proofs to actually understand.

## How to read a lesson

Do not read passively. Every lesson has small exercises marked with `:pencil:`. Do them on paper before reading the answer. The single biggest predictor of whether this material sticks is whether you tried to spell something out yourself and got it wrong first. The north-star table in `docs/foundation/L1.md` is your answer key: pick any row, cover the right-hand column, and try to predict what the expression denotes. When you are routinely right, you understand L1.

## A note on notation

Himark expressions are written in braces: `{a,b,c}`, `{a..z}`, `{cat}{dog}`, `{a, &{b}}`. Math is written in LaTeX-style notation: $\omega$ is the first infinite ordinal, $\varepsilon_0$ is a much larger one you will meet in lesson 3, $\omega^\omega$ sits between them. Lean code, when we show it, is transliterated to plain ASCII with a symbol legend, because these `.md` files are kept ASCII-only; the real `.lean` files use the pretty Unicode symbols and we always point you to them.
