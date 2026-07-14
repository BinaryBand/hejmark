# Himark L1.5 -- Language Surface (interpretation)

L1.5 realizes the L1 object as a matching language and a composable transformation surface. It adds no denotation -- every construct reduces to L1 constructors (the re-admission test). It adds how a universe matches text and a postfix syntax for writing floor operations as pipelines.

## Object

L1 fixes the object as `<alphabet, value, face>` (denotation); this is the shape each field takes once realized -- a direction, not a mandate. Devs pick the representation.

- Alphabet -- a possibly-endless virtual list of spellings. In practice it answers two questions lazily: *does this spelling belong, and where?* (a lookup, spelling -> position or miss) and *what sits at this position?* (an indexer/iterator, position -> spelling).
- Value -- a single point inside an alphabet. Represented as a fixed-sized vector of indexes -- one per factor of its alphabet (one for a flat alphabet). E.g. <`{a..}`,[0],0> is `a`, <`{a..}{a..}`,[1,0],0> is `ba`.
- Face -- an unsigned integer, 0 up, 0 canonical: which spelling of a flat entry. Nothing more. E.g. <`{{b,c}}`,[0],1> is `c`.

## Matching

- Query -- a universe run against text; matches one entry by any face. A query denoting the empty universe matches nothing.
- Capture -- a universe naming one matched `<value, face>` address (L1's coordinates, now read off a hit). Derived, never stored.
- Membership -- matching is set membership: does the text spell an entry? No numeric or ordinal semantics leak in; the matcher knows only spellings.
- Longest-first -- tile the text longest-face-first (maximal munch); where two entries are prefixes of one another, the longer wins. Declaration order never selects a match.
- Zero-width -- the unit's face is the empty spelling; no match is ever accepted on it. The unit exists to be a factor (L1's product identity), not a query.
- Decidability -- text is finite, so at any position only the finitely many faces no longer than the remaining text are candidates, whatever the order type above. (The matching half of L1's bounded transfinitude.)

## Registers

- Every entry's L1 `value` (and its face index) made addressable -- a handle on a matched position. A capture is a register read; nothing is stored.
- Radix -- a universe carries its factor structure, so it also carries the digit alphabet those factors are drawn from. `@0` reads the digit alphabet's value-0 entry: the **zero digit**. For a flat universe the digit alphabet is the universe itself, so `{8,9,10,11,12}@0` is `8`; for a numeral universe over `{0..9}` it is `0`. Nothing else in L1.5 needs to know a value's magnitude -- only which entry sits at zero.

## Transformation primitives

Three, one per field of the object, all total, all taking a **universe** as the argument -- no second type enters the language. Each is compression: the result is always a universe L1 already denotes, so what the primitive adds is a way to *name the function*, never a way to reach a new denotation. A spelling in an argument that names nothing is a no-op, as it is under union and subtraction.

- Alphabet axis -- `keep U` / `drop U`: filter entries by spelling membership in the argument. Pure compression, already in L1: `A[keep B]` is $A \cap B$ (two subtractions) and `A[drop B]` is $A \setminus B$. They earn their place as pipeline-shaped names for constructors the floor already has, not as new power.
- Value axis -- `span U`: keep the entries whose value lies within the window running from the least to the greatest of the argument's spellings, each decoded as a **numeral in the operand's radix** (`{a..z}[span {aa,cc}]` reads `aa` as $0$, not as a two-letter spelling: leading zeros are value-preserving). Generative where the window runs past the operand's own spellings, so it is a re-cut, not a filter. It is the only construct that cuts the value order rather than the spelling order -- the final segment's opposite number -- and it is compression, witnessed by the digit decomposition (below).
- Face axis -- `faces U`: keep the faces spelled in the argument and drop the rest; an entry left with no face drops. This is the one axis L1 hands no constructor: subtraction removes entries, not spellings. It is still compression -- every result is writable longhand as a fold -- but it is the only genuinely new surface L1.5 introduces.

Widths need no numeric type either. All one-character spellings precede all longer ones in shortlex, so a range spanning the code-point set denotes exactly the characters; call it `C`. Then `C` is the universe of one-character spellings, `CC` of two, and `{C,CC}` of one-or-two -- a face-axis argument, written with the constructors.

## The pipeline

- Form -- `<operand> [ <func> <arg>  <func> <arg>  ... ]`: a left-to-right chain of total universe-to-universe transformers.
- Radix -- the digit alphabet is fixed by the operand at the **head** of the pipeline and carried through every stage; a stage never re-reads the radix off its own input. This is what makes `{0..9}[where 8..12 pad 1..2]` fill with `0` (the head's zero digit) while `{8,9,10,11,12}[pad 2]` fills with `8` (its own). It is also why the chain lives in one bracket: split it into `[...][...]` and the second bracket loses the head.

## Worked derivations

The L2 targets, defined over the primitives above -- algebra alone, no built-in named modifiers. `A` is the operand, `D` its radix, `Z` the **fill factor** `{{{}, D@0}}` (a fold of L1's unit with the zero digit: one entry, order type $1$, wearing the empty face and the zero face, so `Z A` re-faces every entry of `A` with a zero-padded spelling without touching a single value).

- `where lo..hi` := `[span {lo,hi}]`. The `..` is the argument pair, not a spelling range.
- `pad w..w'` := `(Z^{w'-1} A)[faces {C^w, ..., C^{w'}}]`. Multiply on the padded faces, then keep the spellings of admissible character width.

| Expression | Denotes | Reduction |
| --- | --- | --- |
| `{0..9}[where 8..12]` | 8, 9, 10, 11, 12 | `{ {8,9}, {1}{0..2} }` |
| `{a..z}[where aa..cc]` | a, ..., z, ba, ..., cc  (55 entries; `aa` = `a` = 0) | `{ {a..z}, {b}{a..z}, {c}{a..c} }` |
| `{8,9,10,11,12}[pad 2]` | 88, 89, 10, 11, 12  (the zero digit is `8`) | `Z = {{{},8}}`; `Z A` faces `8`/`88`, `10`/`810`; `[faces {CC}]` keeps the width-2 spellings |
| `{0..9}[where 8..12 pad 1..2]` | {8,08}, {9,09}, 10, 11, 12 | `Z = {{{},0}}` (head radix); `Z A` faces `8`/`08`, `10`/`010`; `[faces {C,CC}]` keeps widths 1-2, so `8` folds with `08` and `010` drops |

The value-axis reductions are the numeral-range decomposition: a value window is a finite union of products, one per digit width, each with its leading digit cut to the window -- so `span` compresses into union, product, and range, and the widths of the endpoints bound the number of products. The face-axis reductions are folds. Nothing above reaches past the floor.

## Open

- The reductions above are expansions driven by *literal* arguments (`hi`'s width fixes how many products `span` unrolls; `w'` fixes the exponent of `Z`). L1.5 therefore needs no recursion or arithmetic. Whether L2's function definitions may take those widths from a *variable* -- and so must iterate -- is L2's question, not this layer's.

## Finish line

> L1.5 is done when this surface suffices to define `where` and `pad` in L2 -- algebra alone, no built-in named modifiers.
