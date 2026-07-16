# Himark Roadmap

## Layer 1 -- Mathematical Floor (denotation) -- cemented

- The object -- the pointed alphabet `<alphabet, value, face>`; value and face are ordinals below $\varepsilon_0$, below $\omega^\omega$ wherever closure stays linear.
- Constructor floor -- six total constructors: union, subtraction, fold, final segment, product, closure (`&`). Nothing rejects: every boundary case carries a denotation.
- Closure -- the inflationary closure at $\omega$, the union rule read at $\omega$: total on every body, least fixpoint on positive bodies, settled at length-bounded stages on guarded ones.
- Theorems -- positional value (one collision rule across both axes); bounded transfinitude at $\varepsilon_0$, stratified (the linear fragment stays below $\omega^\omega$); fixpoint on settled bodies; compression, not capability.
- Axiom side -- closure and product; final segment is demoted to compression (`{{{}}, &C}` generates every spelling in shortlex), kept as notation the way ranges are.

## Layer 1.5 -- Language Surface (interpretation)

Everything the host implements beyond denotation; the one layer allowed to reject. Its admission rule: a surface construct adds no denotation -- it expands into the floor or it does not enter.

- Matching -- query and capture, text membership, maximal munch, zero-width exclusion; the matcher is scoped to guarded closure bodies (the settlement theorem's fragment), and stepping outside that scope is a diagnostic, never a denotation failure.
- Names -- `uni hex = {0..9,a..f}`: declaration and splice-by-name. Pure compression; the floor's splice rule already anticipates the name.
- Definitions -- `name args := body` rewrite forms and the modifier pipeline `A[f x g y]`; application is substitution over the operand and literal arguments, and every application expands to a floor expression.
- Registers -- the in-language spellings of the expander's metafunctions, so std bodies stay writable: `@0` reads the zero entry of the pipeline head, which is what lets `pad`'s declaration infer its fill (`{8,9,10,11,12}[pad 2]` fills with `8`; one radix rides the whole chain; an empty head degrades the fill to the unit, so `pad` no-ops -- total). Same footing as the `s` in the floor's own `{a..z}` = `{a.., !{s..}}`: notation whose expansion reads the source, never a runtime store -- captures stay on the floor's object. The register list *is* the metafunction inventory made visible, so a new register faces the scrutiny a new axiom does; the inventory is closed at two tokens -- `@` the head itself, `@0` its zero entry -- with `where` written over them for character radixes and the digit-walk decomposition scoped out until a non-character use appears.
- Emit -- `=>` statements, two objects and one join: branches (spans carrying the floor's capture) point into text objects (the document, or a string a template constructs); a query refines a branch per match and guards on no match, a template constructs a string that commits where a branch anchors and continues a sub-branch per interpolation site, and a leading template is detached -- so the whole-document rewrite is the idiom `{spellings} => "..."`, never a special case. The fold carries the transformation (match a later face, emit `$0`, the canonical); casts by value and `<=>` iteration wait in L1_5.md's open list.
- Diagnostics -- compiler errors live here: unknown name, malformed definition, unguarded matcher scope. The floor never rejects, so rejection is interpretation's whole job.

> Finish line: the surface suffices to write all of L2 in-language -- no built-in named modifiers, no host code per entry.

## Layer 2 -- Standard Library (content)

Nothing but in-language declarations over the L1.5 surface: `uni` universes and `:=` definitions. No new denotation, no host code -- every entry must compile away through L1.5's expansion into the six constructors, which is the re-admission test in operational form.

| Expression                     | Denotes                                            |
| ------------------------------ | -------------------------------------------------- |
| `{0..9}[where 8..12]`          | 8, 9, 10, 11, 12                                   |
| `{a..z}[where aa..cc]`         | a, b, ..., z, ba, ..., cc (55 entries; aa = a = 0) |
| `{8,9,10,11,12}[pad 2]`        | 88, 89, 10, 11, 12                                 |
| `{0..9}[where 8..12 pad 1..2]` | {8,08}, {9,09}, 10, 11, 12                         |

## Layer 3 -- Presentation

<!-- TBD: formatting and lint style only; nothing semantic. Compiler errors moved to L1.5, where rejection belongs. -->
