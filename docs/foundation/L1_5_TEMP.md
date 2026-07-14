# Himark L1.5 -- Language Surface (interpretation)

L1.5 realizes the L1 object as a matching language and a composable transformation surface. It adds no denotation -- every construct reduces to L1 constructors (the re-admission test). It adds how a universe matches text and a postfix syntax for writing floor operations as pipelines.

## Object

L1 fixes the object as `<alphabet, value, face>` (denotation); this is the shape each field takes once realized -- a direction, not a mandate. Devs pick the representation.

- Alphabet -- a possibly-endless virtual list of spellings. In practice it answers two questions lazily: *does this spelling belong, and where?* (a lookup, spelling -> position or miss) and *what sits at this position?* (an indexer/iterator, position -> spelling).
- Value -- a single point inside an alphabet. Represented as a fixed-sized vector of indexes -- one per factor of its alphabet (one for a flat alphabet). E.g. <`{a..}`,[0],0> is `a`, <`{a..}{a..}`,[1,0],0> is `ba`.
- Face -- an unsigned integer, 0 up, 0 canonical: which spelling of a flat entry. Nothing more.

## Matching

- Query -- a universe run against text; matches one entry by any face. A query denoting the empty universe matches nothing.
- Capture -- a universe naming one matched `<value, face>` address (L1's coordinates, now read off a hit). Derived, never stored.
- Membership -- matching is set membership: does the text spell an entry? No numeric or ordinal semantics leak in; the matcher knows only spellings.
- Longest-first -- tile the text longest-face-first (maximal munch); where two entries are prefixes of one another, the longer wins. Declaration order never selects a match.
- Decidability -- text is finite, so at any position only the finitely many faces no longer than the remaining text are candidates, whatever the order type above. (The matching half of L1's bounded transfinitude.)

<!-- ## The pipeline

- Form -- `<operand> [ <func> <arg>  <func> <arg>  ... ]`: a left-to-right chain of total universe-to-universe transformers.
- Ambient operand -- the operand is the ambient alphabet for the whole bracket. The value-set flows left to right, but every modifier reads its base and its zero from the bracket operand, never from the previous step's output.
- Plain alphabets -- a universe is only ever a faithful ordered list of spellings. "Digit," "numeral," "zero" live in a modifier, never in the alphabet; the modifier does all interpretation.
- No new denotation -- every modifier's output is a universe the floor already denotes; each concrete instance unrolls to L1 constructors. L1.5 supplies syntax and one iteration primitive, not new denotational power.

## The transformation primitive

One irreducible operator. Everything else -- filtering, fixed-width bands, value cuts, and named functions like `where`/`pad` -- is composition and lives in L2, over this primitive plus the L1 constructors.

- Aggregate -- given a bound `n` read from the ambient alphabet, build the family of width-bands up to `n` and merge them: by **union** (each band contributes distinct values) or by **fold** (each contributes faces of one value). The union-or-fold switch is the whole gap between counting and padding.
- Why it must be primitive -- the floor's `product` has fixed arity and its `union` is finite, so a data-dependent width (bands up to `n`) is unreachable by composition; L2 abstraction can supply it only through recursion, which forfeits totality. Aggregate is the bounded, total stand-in -- bounded exponentiation, staying below $\omega^\omega$.
- No new denotation -- every concrete instance unrolls to a finite union or fold of products. The primitive adds power to *declare* transformations, not to *denote* new universes. -->

## Registers

- Every entry's L1 `value` (and its face index) made addressable -- a handle on a matched position. A capture is a register read; nothing is stored.

## Finish line

> L1.5 is done when this surface suffices to define `where` and `pad` in L2 -- algebra alone, no built-in named modifiers.

## North-star

| Text vs query | Result |
| --- | --- |
<!-- | `ab` vs `{a,b,ab}` | `ab`  (longest-first; the atomic entry, not `a` then `b`) |
| `170` vs `{17,170}` | `170`  (longest wins, not `17`) |
| `07` vs `{0..9}` | no match  (`07` is not an entry) |
| any text vs `{a,!{a}}` | no match  (empty query) | -->

<!-- ## Open questions

- Naming -- the aggregate primitive's name and surface form are provisional, as `where`/`pad` were.
- Munch completeness -- longest-first is deterministic but may leave a tileable string stuck (`{a,ab,bc}` on `abc`). Whether matching stays maximal-munch (stuck is legal) or backtracks to a complete tiling is unresolved.
- Ambient zero over reordered alphabets -- reading base and zero from the operand assumes its declaration order is its counting order; an operand declared out of spelling order needs a stated precondition. -->
