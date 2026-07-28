# Lesson 4: The surface syntax

Lessons 1-3 were the disk: five constructors, total, denoting nothing about text at all. This lesson is L1.5 (`docs/foundation/L1_5.md`) -- "everything the host implements beyond denotation." It is the layer that lets you *write* a Hejmark script that looks like a script (names, definitions, a pipeline syntax, `=>` statements) instead of a bare tree of braces, and the layer that finally says what it means to run a universe against real text.

## The one rule this whole layer obeys

L1.5 has its own version of L1's totality discipline, and it is worth stating up front because it explains a lot of otherwise-surprising behavior: **a surface construct either expands into the five constructors, or it does not enter the language at all.** There is no third option where L1.5 adds a new piece of denotation of its own. This is the **admission rule**, and every section below is really just "here is one more surface form, and here is its expansion."

One consequence trips people up, so name it now: **the floor never rejects, and this layer never guards either.** A malformed script -- an unknown name, a bad arity, a register used somewhere it cannot resolve -- simply has *no expansion*. That is a fact about the text, decided once, at expansion time, the way a program that does not typecheck simply is not a program. It is different in kind from *refusing a program that does compile*, which is the next layer's whole job (L2, lesson 5): bounding a read, refusing an unguarded matcher, stopping a `<=>` that spins forever. L1.5 draws the line between "this has no reading" and "this has a reading but we will not run it unboundedly"; it does not itself enforce the second half.

## Matching: what a universe means against text

Everything before this section was denotation with no text in the picture. Here is where that changes.

- A **query** is a universe run against text: it matches one entry, by any of that entry's faces. An empty query matches nothing -- meaningless, not invalid, exactly as lesson 1 promised.
- **Membership is the whole test.** Matching asks only "does the text spell an entry?" The matcher has no idea what `value` or `face` mean as ordinals; it just checks whether a string is one of the universe's spellings.
- **Capture** is the `<value, face>` pair lesson 1 introduced, read off a hit. It was never bolted on: it *binds* an existing coordinate, it does not create a new one.
- **Longest-first (maximal munch)** -- where one face is a prefix of another, the longer one wins. Declaration order never decides a tie; length does.
- **Zero-width exclusion** -- the empty spelling (the unit's one face, lesson 1) never matches. If it did, everything would match everywhere, infinitely.

**Scope.** Lesson 3's fixpoint theorem said membership is *decidable* on guarded closure bodies (and trivially decidable on anything closure-free), but only *semi*-decidable otherwise. L1.5's matcher is scoped to exactly that decidable fragment. Stepping outside it is a diagnostic here -- this layer only classifies the boundary -- and an actual refusal at runtime is L2's (lesson 5).

**Back-references.** `{$k}` (where a universe can stand) or `$k` as a pipeline argument (`where 0..$2`) reads factor `k` of the *same query*, and only a factor strictly to that query's *left* -- a query's own factors bind left to right as the matcher tries them, so a back-reference can only ever read something already bound. Substituting the face as it actually hit turns every attempted match into an ordinary floor query -- no new denotation, just expansion parameterized by a binding you have not made yet at write time. You will see this everywhere in the bubble-sort example at the end of this lesson: `{@digits}...[below 0..$2 padfree]` reads the *first* number back as the upper bound for comparing the second.

## Names: `uni` and `@`

- **`uni name = {...}`** declares a name that stands wherever a universe can stand -- as a member, a factor, a subtraction operand. It contributes its entries *by splicing*, the same way a closure splices when used as a member (lesson 2) -- never by folding them into one entry.
- **`@name`** is how you *use* a declared name. The `@` sigil exists for exactly one reason: to keep a name from ever being read as a literal spelling. `{cat}` is the three-character face `cat`; `{@cat}` is a splice of whatever `cat` was declared to be. Miss the `@` and you get a face, not a reference.
- **Acyclic.** A name may never reach itself, directly or through others, in its own declaration. `&` is the language's *only* legal self-reference, and it lives on the floor (lesson 2) precisely so that every surface expansion is guaranteed to terminate.
- **Literal faces.** Inside `{}`, every character is exactly the character it is -- whitespace and parentheses included. `{cat dog}` is the single seven-character face `cat dog`; members split on a bare `,` alone. A short list of structural characters (`, { } [ ] ! & @ _ ^ $ " \`) must be escaped with `\` to appear literally, and `\n`, `\t`, `\r` are mnemonic escapes for newline, tab, and carriage return -- which is how a one-line declaration can still carry real whitespace.

## Definitions and the pipeline

`def name params = body`, applied only through a bracketed **modifier pipeline**: `A[f x g y]` runs stage `f` (with argument `x`), then feeds the result into stage `g` (with argument `y`), each stage's result becoming `_` for the next. A zero-parameter name splices bare (`@name`); a parameterized one is only ever reached by applying it in a pipeline stage.

A few things about this that are easy to get backwards:

- **Juxtaposition is always product**, never application. `@a@b` is *not* "apply `a` to `b`" -- it is the product of the two universes, the same adjacency lesson 2 already gave you. This is exactly why application needs its own bracket syntax; there is no ambiguity to resolve because there is no other reading of two things sitting next to each other.
- **Substitution, and nothing more.** Applying a stage replaces the body's parameters with the stage's arguments and `_` with whatever came before it in the pipeline, and keeps expanding until only constructors remain. Definitions are non-recursive (recursion is the closure's job, and only the closure's) and acyclic, so this process always terminates -- the same acyclicity guarantee as names, one level up.
- **The head, and rebinding it.** Every stage inside *one* bracket shares the same **head** -- the pipeline's left operand, not the threaded `_` -- so a fused `A[f g]` pins both stages to `A`. A *new* bracket, `A[f][g]`, rebinds the head: `g`'s head is now `A[f]`. This is how `pad` (lesson 6) reaches the *cut* radix's own `@0` rather than the original one.

Two kinds of numeral parameters exist, and the distinction matters: a **value** parameter (like `where`/`below`'s bounds) is canonicalized in the head's own radix -- `aa` binds the same as `a`, value 0 -- because it names a *position* on the value line. A **count** parameter (a width, an exponent) is a plain decimal numeral regardless of the head, because it feeds the expander's own arithmetic and never names a position at all. `pad 2` is really the degenerate pair `pad 2..2`, reusing union's singleton-case theorem from lesson 2.

**Exponent**, the one piece of repetition notation this layer adds: `A^x..y` is the union of `A^x` through `A^y`, each an iterated product down to `A^0` = the unit -- lesson 2's product-identity theorem is exactly why that base case is well-formed. Both ends of an exponent span must be attained (a decimal numeral, or a parameter that was bound to one), so -- consistent with lesson 2's retirement of open-ended ranges -- there is no open `A^x..` either; unbounded repetition is the closure's alone.

## Registers: the closed inventory

A **register** is an in-language spelling for a read the expander needs that no expression computes on its own -- the same move as `{a..z}` listing its own shortlex interval, just given a token so a *declaration*, not only inline prose, can lean on it. The whole inventory is deliberately small: two tokens, two addressed families, one face-zero read.

| Spelling | Side | Reads |
| --- | --- | --- |
| `@` | expander (pipeline) | the pipeline head as a universe -- every other `@`-read is a read of it |
| `@0` | expander | the head's zero entry -- the degenerate cut `@0..0` |
| `@lo..hi` | expander | the head's value line, cut to values `lo` through `hi`, both attained |
| `$` | emitter (matching) | the hit as it hit -- the bound entry at its bound face |
| `$0` | emitter | the hit's canonical face -- the face axis's zero, matching `@0` on the value axis |
| `$1..$n` | emitter | factor `k` of the query, as it hit, 1-based |

Two things about `@lo..hi` are worth dwelling on, because they connect straight back to lesson 3:

- **No expression selects an entry by value directly** -- there is no way to say "the third entry" other than through this register -- so the value cut is never something you could derive by hand from `@`'s own spellings.
- **Both bounds are always written.** The value line has a least entry (`@0`) but no greatest, mirroring lesson 2's retirement of open-ended ranges: a universe that needs *every* value is the generating closure, written outright (`{0,{1..9,&{0..9}}}`, the canonical-numerals row from lesson 3), never an open register cut.

A short worked table, so the registers stop being abstract:

| Expression | Denotes | Why |
| --- | --- | --- |
| `{0..9}[where 8..12]` | 8, 9, 10, 11, 12 | the value line cut to `8..12`: the width-1 digit `8`, `9`, then width-2 canonicals up to `12` |
| `{a..z}[where aa..cc]` | a, ..., z, ba, ..., cc (55 entries) | `aa` binds canonical as `a`, so the width-1 letters enter the range too |
| `{8,9,10,11,12}[pad 2]` | 88, 89, 10, 11, 12 | here `@0` is `8`; too-narrow and too-wide faces both get stripped |
| `{a,bb}[where a..bbbb]` | a, bb, bba, bbbb | values 0-3; a *spelling* range would also admit `bbaa` (value 4, shortlex-below `bbbb`) -- this is theorem 2's premise failing in the wild |

## Worked derivations: where things actually go

`docs/foundation/L1_5.md` organizes this as three axes, and it is a genuinely useful way to keep the surface's tricks straight:

- **Alphabet axis** -- keeping entries and dropping entries are *both* subtraction: a difference drops the named entries directly; an intersection keeps them by subtracting everything else (`A ∩ B = A \ (A \ B)`, the standard trick).
- **Value axis** -- the closure generates the whole value line, and `where` is the pipeline spelling for cutting a bounded stretch out of it. This is the one read no plain expression computes, which is exactly why it needed a register rather than staying inline. `where` never reads the threaded `_`: it regenerates the value line from the head and cuts it fresh, which is why its body means the same thing at any pipeline stage.
- **Face axis, by fold** -- a fold can carry a *declared* respelling (an input spelling rides as a later face, the output lands at face 0) with no arithmetic involved. What it *cannot* carry is a **cast**: taking a bound value and writing it under a *different* radix (decimal to hex, say, or a unary run's length rendered as a decimal). A cast needs the value read as a value and then re-rendered under a second universe's numerals -- and no expression computes that, and no register spells it. This is a genuine, documented limitation, not an oversight: L1.5's frontier note flags it as the one denotational capability a future surface layer might add, and it would be a new *denotational* addition (growing L1.5), not something L2 could unlock by relaxing a budget.
- **Face axis, by subtraction** -- a width cut (`shorter`/`longer`, lesson 6) is just subtraction applied to "the faces of the wrong width."

## Emit: turning a match into a rewrite

This is the write half of using a universe against text, and it is worth building the vocabulary slowly because the bubble-sort example at the end leans on all of it at once.

- A **text object** is anywhere spellings live: the document a statement runs against, or a string a template builds.
- A **branch** is a span of one text object carrying the capture that bound it -- the span `[start, end]` and the floor's `<value, face>` are one datum seen two ways. Only branches ever cross a `=>` arrow; there is no such thing as a detached captured value floating free of text.
- A **statement** is a chain of **steps** joined by `=>`, top-level only (inside a brace or a quote, `=>` is just literal text). Each step is either a **query** (refines: tiles the incoming branch by matching, one sub-branch per hit, and a query that matches nothing simply stops that branch -- this is how a mid-chain query acts as a *guard*) or a **template** (constructs: `"literal text {{interpolation}}"`, where each `{{...}}` site holds one capture read and renders it into the output).
- A leading query branches into the whole target document; a leading template is *detached* -- it builds a string with nothing bound to real text yet, so the rest of the chain computes over that string and the document itself never changes. (`"seed" => {e} => "E"` matches nothing in your actual document; it just computes `sEEd` off the literal word `seed` and discards it.)
- **`<=>`, contraction**, is the one iterated statement: run the ordinary tile-commit-splice pass, then run it again against the *result*, and keep going until a pass leaves the document completely unchanged -- a fixpoint. Nothing about the arrow declares a measure that proves this terminates in advance; it settles when it settles. Bounding a run that never does is entirely L2's job (lesson 5) -- L1.5 just names the behavior.

## Sentinels: masking without collision

A **sentinel** is a declared name that denotes one entry, one face: a single, fresh *noncharacter* -- a Unicode code point set aside for exactly this, outside the ordinary alphabet (`char`) and distinct from every other sentinel. The floor never learns sentinels exist; a `sentinel` declaration is already a leaf of the five constructors (a `uni` over one lone face), so admission here is immediate.

The reason this is useful rather than merely clever: `char` (lesson 6) *excludes* the noncharacters by construction, so nothing you write against `char` can ever accidentally match a sentinel -- the only thing that ever matches one is its own declared name. Collision with real document content is not merely avoided, it is *unrepresentable*, which is what makes "temporarily mark this spot in the text with an invisible tag, then strip the tag later" a completely sound idiom rather than a hack that might someday collide with user data. (The concrete mechanics -- allocation, the pool size, the ingest guard, the exit strip -- are operational details, and they are L2's; lesson 5 covers them.)

## Diagnostics, briefly

Where no expansion exists at all, the script simply has no reading: an unknown or cyclic name, a malformed definition, a register used outside where it can resolve, an operand token nothing binds, a capture read with no anchoring branch, a factor read past the factors the query actually wrote. None of this is a *runtime refusal* -- it is closer to a syntax error, decided once, at expansion time. Every refusal of a program that *does* compile and *does* denote -- a read past budget, a matcher stepping outside the settled scope, a `<=>` that never reaches a fixpoint, a sentinel at the document boundary -- belongs to L2, next.

## North star: bubble sort

`static/examples/demos/bubble-sort.hmk` is called out in this project's own guidance as the language's north star -- the one script that only round-trips correctly once sentinels, back-references, and contraction all work together at the same time. Read it slowly; every piece is something you now have a name for.

```text
sentinel start
sentinel end

uni c      = {@char,!{\n}}
uni line   = {@c,&@c}
uni d      = {0..9}
uni digits = {@d,&@d}
uni value  = {0,{1..9,&{0..9}}}[padfree]
uni list   = {@value,&{\,}{@value}}
uni sorted = {{@start}{@list}{@end},&{\n}{@start}{@list}{@end}}

{@line} => "{{@start}}{{$}}{{@end}}"
{@start,\,}{@digits}{\,}{0..9}[below 0..$2 padfree]{@end,\,} <=> "{{$1}}{{$4}},{{$2}}{{$5}}"
```

- `c` is every character except newline; `line` is the closure of `c` -- one entry per *whole line*, however long. `d` is a decimal digit; `digits` is the closure of `d` -- one entry per *whole number*, any number of digits.
- `value`, `list`, and `sorted` are never mentioned by either statement, so they change nothing about what the script does -- but they are worth reading anyway, because they document the shape the two active statements are quietly relying on. `value` is lesson 3's canonical-numerals row (`{0,{1..9,&{0..9}}}`) with `padfree` applied, so it is "any numeral, at any padding." `list` is a comma-joined run of those. `sorted` is a newline-joined run of sentinel-wrapped lists -- the well-ordered space the file's own header comment means by "the well-order `@sorted`, which every pass must strictly descend": each swap moves the document one step along that order, which is *a* way to see why the rewrite terminates, even though L2 (lesson 5) never asks a script to declare a measure -- `<=>` just runs until nothing moves.
- **The first statement is a single, uniterated pass.** It matches each line and rewrites it to the same text wrapped in the two sentinels -- `{{@start}}` and `{{@end}}` are template splices of the sentinel faces (the one place a sentinel's face ever appears in text, per lesson-4's names section). After this pass, every line boundary in the document is marked by an invisible, unrepresentable-by-user-text tag.
- **The second statement is the iterated swap.** Its query reads, left to right: either the start sentinel or a comma (`{@start,\,}`), then a number bound as `$2` via `{@digits}`, a literal comma, then a *second* number, then either the end sentinel or a comma. The second number's universe is `{0..9}[below 0..$2 padfree]` -- a back-reference makes the upper bound of the value cut the *first* number's value, `below` makes the cut top-exclusive (strictly less than, not less-or-equal), and `padfree` (lesson 6) means the comparison is by *value*, ignoring how many leading zeros either number happens to be padded with. So the query matches an adjacent pair on one line if and only if the second number is strictly smaller than the first -- a genuine inversion.
- The template swaps them: `"{{$1}}{{$4}},{{$2}}{{$5}}"` -- factor 1 (the left delimiter), factor 4 (the second, smaller number), a comma, factor 2 (the first, larger number), factor 5 (the right delimiter). The delimiters (`$1`, `$5`) are threaded through unchanged, which is what keeps the sentinels or commas exactly where they were.
- `<=>` repeats this until no inversion remains anywhere -- which, for an adjacent-swap rule, is precisely when every line is sorted. The `below` cut is what makes this actually terminate on lines with duplicate values: an inclusive cut would keep re-matching (and re-writing, at a different padding) a value-*equal* pair forever, so the document would never stop moving and the run would spend its whole work budget for nothing.
- At exit, every declared sentinel's face is stripped (lesson 5), so the output is plain text again -- just the sorted line, commas and all.

| Against | Yields | Why |
| --- | --- | --- |
| `3,1,2` | `1,2,3` | each pass swaps an adjacent inversion; iteration settles at the ascending line |
| `10,9` | `9,10` | value order, not shortlex text order: `9` precedes `10` even though the text `"10"` precedes `"9"` |
| `09,3` | `3,09` | `padfree` ignores the leading zero; each numeral re-emits at whatever width it arrived with |
| `007,7` | `007,7` | equal value: the top-exclusive `below` cut refuses to match a value-equal pair, so nothing swaps |
| `2,1\n4,3` | `1,2\n3,4` | the sentinels confine each line's sort to itself |

:pencil: **Exercise.** Before reading the table, predict what `100,99,98` does after one pass of the swap statement, and how many passes `<=>` needs before it stops. (One pass swaps `100,99` -> `99,100,98` is wrong -- walk it left to right and you will find the *first* adjacent inversion is `100,99`, giving `99,100,98`; then the query re-scans and finds `100,98` next, giving `99,98,100`; then `99,98`, giving `98,99,100`. Three swaps, three passes of the fixpoint before a fourth pass changes nothing.)

## What you should now be able to say

- L1.5's own totality-like discipline: a surface construct expands into the five constructors or it does not enter the language; malformed text has no expansion, which is different from L2's refusal of programs that do compile.
- `uni`/`@name` declare and splice; `def`/pipeline brackets apply, substitute, and rebind the head on a new bracket; `A^x..y` compresses repetition into iterated product and union.
- The register inventory is closed at two tokens and three families: `@`/`@0`/`@lo..hi` on the value axis, `$`/`$0`/`$1..$n` on the face axis -- and a value cut is never derivable any other way.
- A cast (reading a value under a *different* radix) is the one thing this surface genuinely cannot express yet, and that is documented, not accidental.
- `=>` chains queries (which refine and guard) and templates (which construct and continue) over branches; `<=>` iterates to a fixpoint with no declared measure.
- Sentinels are masking made sound by construction: unrepresentable in `char`, so collision with real content cannot happen, not merely does not happen.

Next: L2, the layer that turns "this all denotes, and this all expands" into "and it runs to completion on real hardware" -- the rewrites that make execution cheaper without changing meaning, and the refusals that catch everything a total, infinite-capable object could otherwise make you wait on forever.
