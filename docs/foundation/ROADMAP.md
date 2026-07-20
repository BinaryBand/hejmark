# Himark Roadmap

<!-- cspell:words sigiled upto -->

## Layer 1 -- Mathematical Floor (denotation) -- cemented

- The object -- the pointed alphabet `<alphabet, value, face>`; value and face are ordinals below $\varepsilon_0$, below $\omega^\omega$ wherever closure stays linear.
- Constructor floor -- six total constructors: union, subtraction, fold, final segment, product, closure (`&`). Nothing rejects: every boundary case carries a denotation.
- Closure -- the inflationary closure at $\omega$, the union rule read at $\omega$: total on every body, least fixpoint on positive bodies, settled at length-bounded stages on guarded ones.
- Theorems -- positional value (one collision rule across both axes); bounded transfinitude at $\varepsilon_0$, stratified (the linear fragment stays below $\omega^\omega$); fixpoint on settled bodies; compression, not capability.
- Axiom side -- closure and product; final segment is demoted to compression (`{{{}}, &C}` generates every spelling in shortlex), kept as notation the way ranges are.

## Layer 1.5 -- Language Surface (interpretation)

Everything the host implements beyond denotation; the one layer allowed to reject. Its admission rule: a surface construct adds no denotation -- it expands into the floor or it does not enter. The normative surface is `L1_5.md`; the bullets below are its shape, not a second copy.

- Matching -- query and capture, text membership, maximal munch, zero-width exclusion; the matcher is scoped to guarded closure bodies (the settlement theorem's fragment), and stepping outside that scope is a diagnostic, never a denotation failure.
- Names -- `uni hex = {0..9,a..f}`: declaration and `@name` splice-by-name (one sigiled namespace whose reserved names are the registers). Pure compression; the floor's splice rule already anticipates the name.
- Definitions -- `name args := body` rewrite forms and the modifier pipeline `A[f x g y]`; application is substitution over the operand and literal arguments, and every application expands to a floor expression.
- Registers -- the in-language spellings of the expander's metafunctions: expansion-time reads on the same footing as the `s` in the floor's own `{a..z}` = `{a.., !{s..}}`, never a runtime store. The inventory is closed at four tokens (`@`, `@0`, `$`, `$0`) carrying two addressed families -- `@lo..hi` the head's value line by value, `$1..$n` the hit's written factors -- and a new register faces the scrutiny a new axiom does.
- Emit -- `=>` statements joining branches (spans carrying the floor's capture) to text objects: a query refines and guards, a template commits and continues per interpolation site, and `<=>` iterates a statement under a declared measure every pass must strictly descend. A cast by value -- writing a bound value under a second universe -- stays uncomputable: value-indexing across two radixes, which no expression computes and no register spells.
- Diagnostics -- compiler errors live here: unknown name, malformed definition, unguarded matcher scope. The floor never rejects, so rejection is interpretation's whole job.

> Finish line: the surface suffices to write all of L2 in-language -- no built-in named modifiers, no host code per entry.

## Layer 2 -- Standard Library (content)

Nothing but in-language declarations over the L1.5 surface: `uni` universes and `:=` definitions. No new denotation, no host code -- every entry must compile away through L1.5's expansion into the six constructors, which is the admission test in operational form.

| Expression                     | Denotes                                            |
| ------------------------------ | -------------------------------------------------- |
| `{0..9}[where 8..12]`          | 8, 9, 10, 11, 12                                   |
| `{a..z}[where aa..cc]`         | a, b, ..., z, ba, ..., cc (55 entries; aa = a = 0) |
| `{8,9,10,11,12}[pad 2]`        | 88, 89, 10, 11, 12                                 |
| `{0..9}[where 8..12 pad 1..2]` | {8,08}, {9,09}, 10, 11, 12                         |

## Layer 3 -- Presentation

<!-- TBD: formatting and lint style only; nothing semantic. Compiler errors moved to L1.5, where rejection belongs. -->
