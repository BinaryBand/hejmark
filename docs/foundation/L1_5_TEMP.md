# Himark L1.5 -- Language Surface (interpretation)

L1.5 realizes the L1 object as a matching language and a composable transformation surface. It adds no denotation -- every construct reduces to L1 constructors (the re-admission test). What it adds is interpretation: how a universe matches text, and a postfix syntax for writing floor operations as pipelines. It stays faithful like the floor -- nothing is rejected, and any operand must denote, however enormous or nonsense; sanity and rejection are L2+. `where` and `pad` are not here; they are L2 definitions over this surface.

## Matching

- Query -- a universe run against text; matches one entry by any face. A query denoting the empty universe matches nothing.
- Capture -- a universe naming one matched `<value, face>` address (L1's coordinates, now read off a hit). Derived, never stored.
- Membership -- matching is set membership: does the text spell an entry? No numeric or ordinal semantics leak in; the matcher knows only spellings.
- Longest-first -- tile the text longest-face-first (maximal munch); where two entries are prefixes of one another, the longer wins. Declaration order never selects a match. So `{a,b,ab}` reads `ab` as the atomic entry, not `a` then `b`, and `{17,170}` matches `170`, not `17`.
- Decidability -- text is finite, so at any position only the finitely many faces no longer than the remaining text are candidates, whatever the order type above. (The matching half of L1's bounded transfinitude.)

## The pipeline

- Form -- `<operand> [ <func> <arg>  <func> <arg>  ... ]`: a left-to-right chain of total universe-to-universe transformers.
- Ambient operand -- the operand is the ambient alphabet for the whole bracket. The value-set flows left to right, but every modifier reads its base and its zero from the bracket operand, never from the previous step's output.
- Plain alphabets -- a universe is only ever a faithful ordered list of spellings. "Digit," "numeral," "zero" live in a modifier, never in the alphabet; the modifier does all interpretation.
- No new power -- every modifier reduces to L1 constructors, so the pipeline never leaves the floor. L1.5 supplies composable syntax, not capability.

## The transformation surface

The floor constructors in postfix, chainable form -- writing and composing them, nothing more.

- Filter -- `[less B]` = $A \setminus B$ (subtraction over a universe operand); `[only B]` = $A \cap B$ = $A \setminus (A \setminus B)$. The predicate *is* a universe; membership does the work, so no booleans.
- Bands -- the $k$-fold product $A^k$ and adjacency: fixed-width strings over the ambient alphabet. (product)
- Aggregate -- combine a parameterized family by union (distinct values) or by fold (one value, many faces). The union-or-fold switch is the entire gap between counting and padding.
- Cut -- restrict to a value range on the ambient alphabet: final-segment subtraction on the value axis.

## Registers

- Every entry's L1 `value` (and its face index) made addressable -- a handle on a matched position. A capture is a register read; nothing is stored.

## Finish line

> L1.5 is done when this surface suffices to define `where` and `pad` in L2 -- algebra alone, no built-in named modifiers.

## North-star

| Expression | Denotes |
| --- | --- |
| `{a..z}[less {a,e,i,o,u}]` | the 21 consonants  (difference = subtraction) |
| `{0..9}[only {3..7}]` | 3, 4, 5, 6, 7  (intersection = two subtractions) |
| `{0..9}[only {6..}]` | 6, 7, 8, 9  (the predicate ">= 6" is the universe `{6..}`) |
| `{0..9}[only {a..z}]` | {}  (no overlap; filtering is total) |

## Open questions

- Naming -- `less`/`only` (drop/keep? in/out?), and the surface names for bands, aggregate, and cut, are all provisional, as `where`/`pad` were.
- Munch completeness -- longest-first is deterministic but may leave a tileable string stuck (`{a,ab,bc}` on `abc`). Whether matching stays maximal-munch (stuck is legal) or backtracks to a complete tiling is unresolved.
- Ambient zero over reordered alphabets -- reading base and zero from the operand assumes its declaration order is its counting order; an operand declared out of spelling order needs a stated precondition.
