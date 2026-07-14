# Himark L1.5 -- Language Surface (interpretation)

<!-- Working draft. The floor it stands on is L1_TEMP.md; the layer plan is ROADMAP.md. -->

L1.5 is everything the host implements beyond denotation, and the one layer allowed to reject. Its admission rule is the floor's re-admission test read from above: a surface construct adds no denotation -- every application expands into the six constructors -- or it does not enter here; what refuses to expand goes to L1 as an axiom or nowhere. The floor never rejects, so rejection is this layer's whole job.

## Matching

- Query -- a universe run against text; it matches one entry, by any face. A query denoting the empty universe matches nothing; emptiness stays meaningless, not invalid.
- Capture -- the floor's `<value, face>` read off a hit. The object already carries the pair, so a capture is a binding, never a store; no operand holds a text field.
- Membership -- matching is set membership: does the text spell an entry? No value or ordinal semantics leak in; the matcher knows only spellings.
- Longest-first -- tile the text longest-face-first (maximal munch); where one face is a proper prefix of another, the longer wins. Declaration order never selects a match.
- Zero-width -- the unit's face is the empty spelling, and no match is ever accepted on it. The unit exists to be a factor (the product identity), not a query.
- Scope -- the matcher is total on queries whose closure bodies are all guarded: the settlement theorem decides a length-$L$ spelling by stage $L + 1$, and finite text offers only finitely many candidate lengths, whatever the order type above (closure-free queries were always in scope by the same finiteness). An unguarded or negative body still denotes -- the floor's totality -- but only semi-settles, so matching against it is out of scope: the diagnostic below, and this layer's one genuine residue.

## Names

- `uni name = {...}` -- a declaration; the name stands wherever a universe stands (member, factor, subtraction operand), contributing entry-wise by the floor's splice rule -- which is also what makes a name the way to union sub-universes without folding them, since splice spreads where a braced member quotients.
- Acyclic -- a name may not reach itself through its declaration, directly or through other names. `&` is the language's only self-reference, and it lives on the floor; acyclicity is what keeps every expansion finite.

## Definitions

- Form -- `name params := body`, applied through the modifier pipeline `A[f x g y]`: stages left to right, each stage's result the next stage's operand.
- Substitution -- application replaces the body's parameters with the literal arguments and the operand token `_` with the stage operand; the result is an expression over names, registers, and the floor, and expansion continues until only constructors remain. Definitions are non-recursive (recursion is the closure's) and acyclic like names, so expansion terminates.
- Head -- registers read the pipeline head, not the stage operand, and a definition invoked inside another body shares the caller's head: one radix rides the whole chain. `{0..9}[where 8..12 pad 1..2]` fills with `0` because the head is `{0..9}`, whatever `where` left in the pipe.
- Numeral parameters -- a parameter written as a numeral or numeral pair (`lo..hi`) binds canonicalized in the head radix: leading zero digits strip, so `aa` binds as `a` (value 0 either way). Canonicalization is a rule of binding, priced with the registers below.

## Registers

- The in-language spellings of the expander's metafunctions -- the reads a written body needs that no expression can compute. The precedent is the floor's own bounded range: `{a..z}` = `{a.., !{s..}}` computes the successor `s` at expansion time; a register is the same move given a token, so that declarations, and not just spec prose, can lean on it.
- `@0` -- the zero entry of the pipeline head. On an empty head there is no zero entry and `@0` reads as the unit, so a fill built on it no-ops -- total, in the floor's manner.
- The inventory, closed: the shortlex successor (the floor's own, no token), numeral-parameter canonicalization (a binding rule, no token), and `@0`. One token in the language. A new register faces the scrutiny a new axiom does -- each is a hole in "the language writes its own std" -- and the finish line is measured by the inventory staying this size.

## Worked derivations

The old surface shipped three transformation primitives -- `keep`/`drop` (alphabet), `span` (value), `faces` (face) -- and two scoped residues. All three primitives dissolve into the floor, and the residues with them.

- Alphabet axis -- `keep`/`drop` are intersection and difference, on the floor's compression list since before this layer existed.
- Value axis -- the closure generates the value line, so `span` is a definition, not a primitive. `numerals` below is the canonical numerals of the head radix in value order: the zero digit first, then the closure's stages width by width, product order within a width already being value order. `where` cuts it with a spelling range: over a character radix, value order and shortlex agree on canonical numerals, so the range cuts the value line exactly, and the order of the result is inherited from `numerals` through two subtractions.
- Face axis -- the axis the floor hands no constructor is cut by **claim and subtract**: union the unwanted spellings in first, let the collision rule strip those faces from the later entries (a claimed spelling drops from every later claimant), then subtract the claimants back out. The collision rule is the face-axis scalpel; `faces` needed no primitive, only an idiom.

The std that the finish line asks for, written over this surface -- `C` is the code-point set as a bounded range, the one `uni` the spec seeds:

```
uni spellings   = {{{}}, &C}                                  -- every spelling, in shortlex
fill            := {{{}, @0}}                                 -- one entry, faced empty and zero
nonzero         := {_, !{@0}}
numerals        := {@0, {nonzero, &_}}                        -- the value line of the head radix
shorter w       := {spellings, !{C^w spellings}}              -- widths below w
upto w          := {shorter w, C^w}                           -- widths at most w
longer w        := {spellings, !{upto w}}                     -- widths above w
where lo..hi    := {numerals, !{numerals, !{ {lo..hi} }}}     -- the value line cut by a spelling range
pad w..w'       := {shorter w, longer w', fill^{w'} _, !{shorter w}, !{longer w'}}
```

`pad` is the claim-and-subtract idiom end to end: `fill^{w'}` gives every entry its faces from bare up to `w'` extra fills, `shorter w` has already claimed every spelling too narrow and `longer w'` every spelling too wide, collision strips those faces from the filled entries, and the two subtractions remove the claimants -- no arithmetic on `w'` needed, since the overshoot faces land in `longer w'` regardless.

| Expression | Denotes | Why |
| --- | --- | --- |
| `{0..9}[where 8..12]` | 8, 9, 10, 11, 12 | `numerals` cut by `{8..12}`: width-1 digits from 8, width-2 canonicals to 12 |
| `{a..z}[where aa..cc]` | a, ..., z, ba, ..., cc  (55 entries) | `aa` binds canonical as `a`, so the width-1 numerals enter the range |
| `{8,9,10,11,12}[pad 2]` | 88, 89, 10, 11, 12 | `@0` is `8`; `shorter 2` claims `8`, `9`; `longer 2` claims `810`, `888`, ... |
| `{0..9}[where 8..12 pad 1..2]` | {8,08}, {9,09}, 10, 11, 12 | head fills `0`; widths 1-2 both legal, so `8` keeps both faces; `010` is claimed |

## Diagnostics

- Errors live here and only here: unknown or cyclic name, malformed definition or arity, a register outside a definition body, a matcher run against an unguarded closure body. The floor never rejects, so every rejection is an interpretation refusing a scope, never an expression failing to denote.
- Emptiness is not an error: a query denoting the empty universe matches nothing and says so. Meaningless stays legal; whether to warn is L3's taste, not this layer's law.

## Open

- `where` over a non-character radix -- value order and shortlex disagree there (`128` sits before `811` at values 20 and 3), so the spelling-range cut is wrong and the bounded digit-walk decomposition would cost digit-read registers. Scoped to character radixes until a use appears; the closure keeps the general value line denotable either way.
- The operand token -- `_` is provisional; whatever the grammar picks must be legal as member and factor.
- Canonicalization -- carried as a binding rule so that `where`'s body stays writable; if a body ever needs to canonicalize something other than a bound parameter, it becomes a token and grows the inventory.

## Finish line

> L1.5 is done when the L2 std -- `uni hex = {0..9,a..f}`, `where`, `pad` -- is written over this surface exactly as the derivations above spell it, with the register inventory no larger than it is on this page.
