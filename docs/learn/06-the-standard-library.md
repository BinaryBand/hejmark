# Lesson 6: The standard library

L3 (`docs/foundation/L3.md`) is the shortest of the four normative specs, and it should be: by the time you reach it, there is nothing new to invent. L3 is `uni` and `def` declarations, written entirely over the L1.5 surface, with **no host code and no new denotation** -- every single entry has to expand into the five constructors, exactly the admission test lesson 3 described, now applied to a whole library instead of one expression. The one exception, and it proves the rule: `char`, the single `uni` the host seeds directly, because "every code point Unicode has" is not something you could plausibly type out as a literal union.

Read this lesson as a worked demonstration that lessons 1-5 were not just theory -- every line below is five constructors and a handful of registers, nothing else.

## The inventory

| Entry | Definition | Denotes |
| --- | --- | --- |
| `char` | *host-seeded* | the code points less the noncharacters -- the writable alphabet |
| `hex` | `{0..9,a..f}` | the hex radix |
| `str` | `{{{}},&@char}` | every spelling, in shortlex |
| `fill` | `{{{},@0}}` | one entry, faced empty and `@0` |
| `shorter w` | `{_,!{@char^w_}}` | the operand's spellings narrower than `w` |
| `upto w` | `{_[shorter w],@char^w}` | the operand's spellings of width at most `w` |
| `longer w` | `{_,!{_[upto w]}}` | the operand's spellings wider than `w` |
| `where lo..hi` | `{@lo..hi}` | the head's value line, cut by value (both bounds attained; no open cut) |
| `below lo..hi` | `{@lo..hi,!{@hi..hi}}` | that cut less its top endpoint (half-open `lo..hi`) |
| `pad w..w'` | `{@fill^{w'}_,!{@str[shorter w]},!{@str[longer w']}}` | each entry filled with `@0` to a width in `w..w'` |
| `zeros` | `{{{}},&@0}` | the `@0`-runs of the head, empty included |
| `zfold` | `{{@zeros}}` | one entry wearing every `@0`-run |
| `padfree` | `{@zfold_}` | every entry at every `@0`-padding |

Take a moment on the first genuinely surprising one: **`str` is `{{{}},&@char}`** -- the unit, unioned with itself-times-every-character, closed. That is *exactly* lesson 2's construction for "every spelling in shortlex order," the very thing that used to need a sixth axiom (`{a..}`, final segment) and now does not. `str` is not a primitive at all; it is the closure, spelled once in the standard library so nobody else has to spell it by hand. Every time you reach for "any string" in a Hejmark script, you are reaching for an ordinary closure.

`where` is almost embarrassingly simple once you see it: `where lo..hi` is *defined* as `{@lo..hi}` -- it is a one-line `def` that does nothing but hand back the register lesson 4 introduced. The surface keyword and the register are the same object; `where` exists purely so a script can write `[where 8..12]` instead of needing bare register syntax at the top level.

`below` demotes the same way L2's rewrite table (lesson 5) assumed it would: it is `where`'s cut with its own top endpoint subtracted back off (`{@hi..hi}`), which is why L2's value-cut collapse has to check *both* halves independently before it can fold a `below` down to a plain range.

## `pad` and `padfree`, worked slowly

These two are worth more attention because the bubble-sort script (lesson 4) leans on `padfree`, and the pair is a nice small lesson in "no arithmetic, just faces":

- **`pad w..w'`** starts from `@fill^{w'}_` -- the operand, with up to `w'` copies of `fill` (`{{{},@0}}`, one entry faced both empty and `@0`) multiplied on. Because `fill` itself has two faces, each multiplication doubles the *face* count without touching the *value* axis at all: this is pure face-axis work, lesson 2's subtraction-reaches-faces idea generalized. The two subtractions then strip whatever came out too narrow (`shorter w`) or too wide (`longer w'`), leaving exactly the faces whose width lands in `w..w'`. No arithmetic ever runs on `w'` itself; the overshoot faces fall to the `longer w'` subtraction regardless of what `w'` was.
- **`padfree`** is what happens when you refuse to cap that process. `zeros` (`{{{}},&@0}`) is structurally `str` with `@0` standing in for `@char` -- the closure of one code point instead of the whole alphabet, so it denotes every run of `@0`, including none. `zfold` folds that closure into a *single* entry (lesson 2's fold-over-an-unbounded-operand: still total, still one entry, just now an entry with infinitely many faces instead of `{{}}`'s one). `padfree` is the product of that one entry with the operand -- so every entry gets every possible amount of zero-padding, uncapped, hung entirely on the face axis. The value axis never moves; `{@zfold_}` is `_`'s value line, untouched.

This is exactly why `padfree` was the right tool for the bubble-sort comparison in lesson 4: comparing `09` and `9` by *value* while ignoring how each was padded is precisely "match at any face this entry wears," and `padfree` is what puts "any amount of padding" onto the face axis so ordinary membership does that comparison for free.

One real limitation worth knowing, because it is the same one lesson 4 flagged for casts: **matching against a `padfree` result stays inside the decidable fragment (membership decides it fine), but *canonically reading* one does not** -- an entry with infinitely many faces has no well-defined "list all of them," so a `$0`/`digits`-style read there is exactly the kind of read L2's read budget (lesson 5) exists to refuse. `pad`'s capped version is what keeps a canonical read possible when you actually need one.

## In action

| Expression | Denotes |
| --- | --- |
| `{0..9}[where 8..12]` | 8, 9, 10, 11, 12 |
| `{0..9}[below 8..12]` | 8, 9, 10, 11 |
| `{a..z}[where aa..cc]` | a, b, ..., z, ba, ..., cc (55 entries; `aa` = `a` = value 0) |
| `{8,9,10,11,12}[pad 2]` | 88, 89, 10, 11, 12 (here `@0` = `8`) |
| `{0..9}[where 8..12 pad 1..2]` | {8,08}, {9,09}, 10, 11, 12 |

Two entries in that pipeline compose left to right and rebind the head as they go (lesson 4): `where 8..12 pad 1..2` first cuts the value line to `8..12`, and `pad`'s stage then reads `@0` off *that* cut universe (`8`), not off the original `{0..9}` -- this is exactly the "new bracket rebinds the head" rule earning its keep.

## Why the width rows only ever touch `@str`

`shorter`, `upto`, and `longer` are defined generically (over `_`, whatever operand you hand them), but they cut *exactly* only on **suffix-closed** operands -- universes where every tail of a member is itself a member. `@str` (every spelling) obviously has this property; an arbitrary universe generally does not. That is why every other std entry that needs a width cut (`pad`, in particular) always writes `@str[shorter w]`, never `_[shorter w]` -- reaching for the one universe the cut is actually exact over, rather than the pipeline's current operand, which might not be suffix-closed at all.

## The admission test, one more time

Every entry in this file is a `uni` or a `def`, and every one of them, chased down through its declarations (`@name` resolves acyclically, lesson 4), bottoms out in the five constructors plus registers -- nothing else. That is not a coincidence or a style guideline; it is L3's entire admission rule, restated from lesson 3's "compression, not capability" theorem one layer up: a standard-library entry earns its place exactly the way a piece of surface notation does, by proving it adds convenience and not power.

## What you should now be able to say

- L3 has exactly one host-seeded primitive (`char`); everything else, including `str` -- "any string" -- is ordinary declarations over the L1.5 surface, expanding into the five constructors.
- `str` is literally lesson 2's "closure of the unit over every character" construction, now named so nobody writes it by hand.
- `where`/`below` are thin wrappers over the `@lo..hi` register; `pad`/`padfree` are pure face-axis work (extra faces via `fill`/`zeros`/`zfold`), with no arithmetic on the width bound itself.
- `padfree` puts unbounded padding on the face axis, which is exactly why matching it stays decidable while canonically reading it does not.
- Width cuts (`shorter`/`upto`/`longer`) are exact only on suffix-closed operands, which is why the std always routes them through `@str`.

Next: we leave the language itself and go look at how a `.hmk` file actually becomes a rewritten document -- the pipeline `hejmark/core/` runs from source text to spliced output, and the hard boundary between the code that compiles a script and the code that runs one.
