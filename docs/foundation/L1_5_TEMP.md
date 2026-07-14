# Himark L1.5 -- Language Surface (interpretation)

L1.5 realizes the L1 object as a matching language and a composable transformation surface. It aims to add no denotation -- every construct reduces to L1 constructors (the re-admission test), which holds for every construct here except the two corners recorded in Open. It adds how a universe matches text and a postfix syntax for writing floor operations as pipelines.

## Object

L1 fixes the object as `<alphabet, value, face>` (denotation); this is the shape each field takes once realized -- a direction, not a mandate. Devs pick the representation.

- Alphabet -- a possibly-endless virtual list of spellings. In practice it answers two questions lazily: *does this spelling belong, and where?* (a lookup, spelling -> position or miss) and *what sits at this position?* (an indexer/iterator, position -> spelling).
- Value -- a single point inside an alphabet. Where the alphabet is a single product, a vector of indexes -- one per factor (one for a flat alphabet) -- is the natural representation. E.g. <`{a..}`,[0],0> is `a`, <`{a..}{a..}`,[1,0],0> is `ba`. The vector is not fixed-size across a whole alphabet, though: a union of products of different arity (which the `where` reductions below make routine) gives entries of differing width, so the representation must carry which summand an entry came from, or fall back on the ordinal the positional-value theorem assigns it.
- Face -- an unsigned integer, 0 up, 0 canonical: which spelling of a flat entry. Nothing more. E.g. <`{{b,c}}`,[0],1> is `c`.

## Matching

- Query -- a universe run against text; matches one entry by any face. A query denoting the empty universe matches nothing.
- Capture -- a universe naming one matched `<value, face>` address (L1's coordinates, now read off a hit). Derived, never stored.
- Membership -- matching is set membership: does the text spell an entry? No numeric or ordinal semantics leak in; the matcher knows only spellings.
- Longest-first -- tile the text longest-face-first (maximal munch); where one entry's face is a proper prefix of another's, the longer wins. Declaration order never selects a match.
- Zero-width -- the unit's face is the empty spelling; no match is ever accepted on it. The unit exists to be a factor (L1's product identity), not a query.
- Decidability -- text is finite, so at any position only the finitely many faces no longer than the remaining text are candidates, whatever the order type above. (The matching half of L1's bounded transfinitude.)

## Registers

- Every entry's L1 `value` (and its face index) made addressable -- a handle on a matched position. A capture is a register read; nothing is stored.
- Radix -- a universe carries its factor structure, so it also carries the alphabets those factors are drawn from: the radix is the **vector** of factor alphabets that positional value already reads, one per place, not a single alphabet. For a flat universe the vector has one entry, the universe itself, so `{8,9,10,11,12}@0` is `8`; for a numeral universe over `{0..9}` every place is `{0..9}` and it is `0`. `@0` reads the value-0 entry of the place it lands in -- the **zero digit** -- so a heterogeneous product (`{b,c}{a..}`) has a zero digit per place (`b`, then `a`) and no single one. Nothing else in L1.5 needs a value's magnitude, only which entry sits at zero.

## Transformation primitives

Three, one per field of the object, all total, all taking a **universe** as the argument -- no second type enters the language. Each is intended as compression: the result is a universe L1 already denotes, so what the primitive adds is a way to *name the function*, never a way to reach a new denotation. That is established for `keep`/`drop` outright, for `span` over a bounded window, and for `faces` over a finite operand; the remaining two corners are the Open section below, and until they close the claim is a design intent, not a theorem. A spelling in an argument that names nothing is a no-op, as it is under union and subtraction.

- Alphabet axis -- `keep U` / `drop U`: filter entries by spelling membership in the argument. Pure compression, already in L1: `A[keep B]` is $A \cap B$ (two subtractions) and `A[drop B]` is $A \setminus B$. They earn their place as pipeline-shaped names for constructors the floor already has, not as new power.
- Value axis -- `span U`: decode every spelling of the argument as a **numeral in the operand's radix** (`{a..z}[span {aa,cc}]` reads `aa` as $0$, not as a two-letter spelling: leading zeros are value-preserving), and keep the entries whose value lies within the window running from the least to the greatest of those *decoded values*. (The unit is a legal argument anywhere, so `A[span {{}}]` is reachable; the empty spelling decodes as the empty sum, $0$.) Endpoints are chosen on the value axis, not the spelling axis: leading zeros drive the two orders apart -- for `{z,aa}` the shortlex-least spelling `z` decodes to $25$ and the shortlex-greatest `aa` to $0$ -- so reading the endpoints off spelling order would invert the window. Total on both boundary cases, in the same shape as the alphabet axis: an empty argument decodes to no values, and an empty window keeps nothing, so `A[span {}]` is the empty universe; an argument with no greatest decoded value (`{a..}`, itself unbounded) yields a window with no upper endpoint -- the value-axis final segment, which is the right answer for the construct billed as the final segment's opposite number. Generative where the window runs past the operand's own spellings, so it is a re-cut, not a filter. It is the only construct that cuts the value order rather than the spelling order. Over a bounded window it is compression, witnessed by the digit decomposition below; the unbounded window buys its totality at the price of that witness, and is an open question.
- Face axis -- `faces U`: keep the faces spelled in the argument and drop the rest; an entry left with no face drops. This is the one axis L1 hands no constructor: subtraction removes entries, not spellings. It is still compression over a **finite** operand, where the result is written longhand as a fold, entry by entry -- which is all the worked derivations below ask of it, since each one hands `pad` the finitely many entries a bounded `where` window admits. That is a property of those derivations, not of `pad`: `pad` over an infinite operand is grammatical (`{a..}[pad 2]`, or any `pad` behind an unbounded window), and it inherits the open question wholesale. Over an infinite operand the longhand is unknown (below). It is the only genuinely new surface L1.5 introduces.

Widths need no numeric type either. All one-character spellings precede all longer ones in shortlex, so a range spanning the code-point set denotes exactly the characters; call it `C`. Then `C` is the universe of one-character spellings, `CC` of two, and `{C,CC}` of one-or-two -- a face-axis argument, written with the constructors.

## The pipeline

- Form -- `<operand> [ <func> <arg>  <func> <arg>  ... ]`: a left-to-right chain of total universe-to-universe transformers.
- Radix -- the digit alphabet is fixed by the operand at the **head** of the pipeline and carried through every stage; a stage never re-reads the radix off its own input. This is what makes `{0..9}[where 8..12 pad 1..2]` fill with `0` (the head's zero digit) while `{8,9,10,11,12}[pad 2]` fills with `8` (its own). It is also why the chain lives in one bracket: split it into `[...][...]` and the second bracket loses the head.

## Worked derivations

The L2 targets, defined over the primitives above -- algebra alone, no built-in named modifiers. `A` is the operand, `D` its radix, `Z` the **fill factor** `{{{}, D@0}}` -- a fold of L1's unit with the zero digit of the place `Z` prefixes (the most significant one). One entry, order type $1$, wearing the empty face and the zero face, so `Z A` re-faces every entry of `A` with a zero-padded spelling without touching a single value. In `Z^n` the same fill spelling arises from more than one factor; L1's face-axis no-op keeps the lower-valued one, so `Z^2` wears exactly ``, `0`, `00` rather than four faces.

- `where lo..hi` := `[span {lo,hi}]`. The `..` is the argument pair, not a spelling range.
- `pad w..w'` := `(Z^{w'-1} A)[faces {C^w, ..., C^{w'}}]`. Multiply on the padded faces, then keep the spellings of admissible character width.

| Expression | Denotes | Reduction |
| --- | --- | --- |
| `{0..9}[where 8..12]` | 8, 9, 10, 11, 12 | `{ {8,9}, {1}{0..2} }` |
| `{a..z}[where aa..cc]` | a, ..., z, ba, ..., cc  (55 entries; `aa` = `a` = 0) | `{ {a..z}, {b}{a..z}, {c}{a..c} }` |
| `{8,9,10,11,12}[pad 2]` | 88, 89, 10, 11, 12  (the zero digit is `8`) | `Z = {{{},8}}`; `Z A` faces `8`/`88`, `10`/`810`; `[faces {CC}]` keeps the width-2 spellings |
| `{0..9}[where 8..12 pad 1..2]` | {8,08}, {9,09}, 10, 11, 12 | `Z = {{{},0}}` (head radix); `Z A` faces `8`/`08`, `10`/`010`; `[faces {C,CC}]` keeps widths 1-2, so `8` folds with `08` and `010` drops |

The value-axis reductions are the numeral-range decomposition: a **bounded** value window is a finite union of products of ranges, grouped by digit width -- so `span` over two finite endpoints compresses into union, product, and range. (An unbounded window is the open question below.) Every numeral in the decomposition is **canonical**: leading-zero-free, so each value is spelled once. The width of an endpoint always means the width of its canonical spelling -- `aa` decodes to $0$ and so has width 1, not 2 -- which keeps the decomposition independent of how the endpoint was spelled, as "leading zeros are value-preserving" already promises. A width is then *boundary* if it is the canonical width of an endpoint, and *interior* if it falls strictly between the two.

- An interior width contributes one product: the leading digit runs from the **successor of the zero digit** to the greatest digit, every later digit over the full radix. The leading digit must start past zero, because a leading zero would re-spell a value the next width down already holds, and union no-ops on spellings, not values -- so `{a}{a..z}` would re-enter values 0-25 as fresh entries and corrupt the value order. Canonical widths are what make this safe to state universally: width 1 can never be interior, since a window reaching below the smallest two-digit value contains $0$, which forces the low endpoint's canonical width to be 1.
- A boundary width unrolls into at most width-many products, one per digit position, and it is not always the leading digit that gets cut. Walking the **low** endpoint: at the last position, pin its earlier digits and cut that digit up from its own value; at each earlier position $i$, pin the digits before $i$, cut digit $i$ up from the *successor* of the endpoint's digit, and let the rest run full. Walking the **high** endpoint is the mirror, cutting downward -- with one asymmetry: at the leading position the cut floors at the successor of the zero digit, never at zero itself, which is the clause the table's `{b}{a..z}` is already obeying. Hence `{a..z}[where aa..cc]` gives `{a..z}` at width 1 (the low endpoint `a`, cut up) and `{b}{a..z}`, `{c}{a..c}` at width 2 (the high endpoint `cc`, cut down at each position). One product per width does not suffice: a window of 8..134 over `{0..9}` needs both `{1}{0..2}{0..9}` and `{1}{3}{0..4}` for width 3 alone.
- Where the endpoints **share** a width, the two walks meet inside it: the low walk cuts upward, the high walk cuts downward, and at the first position where the endpoints' digits differ a single product spans between them. A window of 12..57 over `{0..9}` is `{1}{2..9}` (up from the low), `{2..4}{0..9}` (between), `{5}{0..7}` (down from the high).

So the number of products is bounded by the sum of the endpoint widths, not by the count of widths. The face-axis reductions are folds. Nothing above reaches past the floor -- modulo the two open questions below.

## Open

- `span` over an **unbounded** window has no exhibited longhand. The digit decomposition witnesses compression only for two finite endpoints: it is a finite union of products of ranges, bounded by the sum of the endpoint widths, and both clauses fail once the window has no upper endpoint, which spans infinitely many widths. A reduction looks likely rather than certain: canonical numerals are leading-zero-free, and for those, value order and shortlex order coincide, so an unbounded window should be a final segment over the canonical-numeral universe -- reachable, if at all, by universe-operand subtraction (carve the non-digit characters and the leading-zero spellings out of a final segment). Whether that carve is expressible by a *finite* subtraction is exactly what needs checking; until it is, the value axis has the same trilemma as the face axis -- find the scheme, scope `span` to bounded windows, or promote the unbounded case to an L1 axiom.
- `faces` over an infinite operand has no exhibited longhand. The finite case reduces to a fold per entry, and that is what the derivations use; but `(Z {a..})[faces CC]` -- keep the filled face of every one-character entry and the bare face of every two-character one -- names an infinite family of folds, and no finite L1 expression for it is known. Either a reduction scheme is found (as the digit decomposition witnesses `span`), or `faces` is scoped to finite operands, or it is promoted from compression to an L1 axiom -- the re-admission test admits no fourth answer.
- The reductions above are expansions driven by *literal* arguments (`hi`'s width fixes how many products `span` unrolls; `w'` fixes the exponent of `Z`). L1.5 therefore needs no recursion or arithmetic. Whether L2's function definitions may take those widths from a *variable* -- and so must iterate -- is L2's question, not this layer's.

## Finish line

> L1.5 is done when this surface suffices to define `where` and `pad` in L2 -- algebra alone, no built-in named modifiers.
