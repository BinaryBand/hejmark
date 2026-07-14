# Himark L1 -- Mathematical Floor (denotation)

The axiomatic floor: the one object, the constructors that build it, and the theorems they force. L1 fixes which universes *exist* and how they compose. Using a universe against text -- matching, query, capture -- is L1.5. Nothing here rejects or interprets.

## The object

- Face -- a spelling naming an entry; one entry may wear several (a fold), ordered by declaration and indexed from 0; the index-0 face is canonical.
- Entry -- one member of an alphabet.
- Alphabet -- a well-ordered set of entries, ordered by declaration. Virtual: denoted, never materialized, possibly infinite.
- Spelling order -- shortlex over spellings (shorter first, ties by code point). The code-point set is finite, so this is a well-order of type $\omega$; the order every cut cuts.
- Universe -- *the object*: a pointed alphabet `<alphabet, value, face>`, a virtual list paired with one position. `value` picks the entry: an ordinal below $\omega^\omega$ -- a natural for a flat alphabet, mixed radix over a product's factors (positional value, below). `face` picks the spelling: an index into that entry's faces, **resting at 0** (the canonical face), non-zero only when a fold's later spelling hit. The pair `<value, face>` is the **capture**, carried at the floor, not bolted on above. A written universe leaves `value` free to range; matching (L1.5) binds `value` to one entry and `face` to the spelling that hit. `face` never changes the denotation -- every face names the same member -- so it rests where `value` ranges.
- Empty universe -- the empty alphabet (`{a,!{a}}`), order type $0$: no entry, so no position to bind -- the object's only nullability. Legal and denotable; emptiness is meaningless, not invalid.

## The constructors

Five, all total; they build every universe.

- Union `,` -- append a universe's entries, in its order, skipping any already present; a lone spelling is the singleton case. Idempotent, associative, not commutative.
- Subtraction `!{...}` -- remove a universe's entries where present and renumber; an absent entry is a no-op. Dual to union over the same membership test.
- Fold `{...}` as member -- quotient several faces onto one entry; a claimed spelling drops. Depth flattens: `{a,{b,{c,C}}}` = `{a,{b,c,C}}`.
- Final segment `{a..}` -- every spelling from `a` onward in spelling order, by the union rule. Unary: one cut, no right endpoint, no infinity token. Unboundedness is the missing second cut.
- Product `{cat}{dog}` -- entries are tuples, one per factor, spelled by concatenation, ordered by positional value. Total (empty factor gives the empty universe). Finite factors flatten (compression); an infinite factor does not, so product is a constructor, not notation.

The universe operand on union and subtraction is axiomatic: an entry-wise step adds or removes finitely many entries, while `{a.., !{ {a..}{b}{a..} }}` -- every spelling with no interior `b`-seam -- needs infinitely many removals and is unreachable by any finite iteration of entry-wise steps.

## The theorems

Forced by the object, never postulated.

- Positional value -- a tuple $p_0 \ldots p_{k-1}$ over factor order types $b_i$ sits at $\sum_i W_i \cdot \mathrm{value}(p_i)$, summed most-significant term first with weight $W_i = b_{k-1} \cdot b_{k-2} \cdots b_{i+1}$ on the left of its digit: mixed radix. The face axis composes identically over per-entry face counts. Finite factors give naturals, where the order of multiplication is invisible; an infinite factor gives an ordinal -- Cantor normal form at base $\omega$ -- where it is load-bearing: $n \cdot \omega = \omega$ collapses any digit placed on the left. Rank equals value only when the factors decode uniquely: concatenation is not injective (`{a,ab}{c,bc}` spells `abc` twice; the union no-op keeps the lower value), and membership survives the drop where rank and order type need not.
- Bounded transfinitude -- order types are the ordinals below $\omega^\omega$: closed under every constructor (union adds, fold and subtraction shrink, product multiplies at most, and collision only shrinks) and never reaching the bound, since every expression is finite. Union alone gives $\omega$ plus a finite tail; product climbs -- `{b,c}{a..}` is $\omega \cdot 2$, `{b}{a..}{b}{a..}` is $\omega^2$. Collision alone does not decide the type: each drop keeps the least-valued split, and the surviving least splits do. In `{b}{a..}{b}{a..}` the seams collide (`babba` is both `b|a|b|ba` and `b|ab|b|a`), yet every pair with a `b`-free first segment is its own least split -- infinitely many full $\omega$-blocks survive, cofinally, so $\omega^2$ stands. In `{a..}{a..}` the least split pins the prefix to length at most 2, only finitely many blocks survive, and the type collapses to $\omega \cdot k$, $k$ finite. (The matching consequence, decidability over finite text, is L1.5.)
- Compression, not capability -- these notations denote only what the constructors already reach, adding no power:
  - Bounded range -- `{a..z}` = `{a.., !{s..}}`, with `s` the successor of `z`.
  - Finite adjacency -- `{cat}{dog}` = `{catdog}`.
  - Splice -- spread a named universe's entries into a `,` or `!{...}` slot: the operand rule by name, no new notation.
  - Difference -- $A \setminus B$ = subtraction over a universe operand: `{ ...A..., !{...B...} }`.
  - Intersection -- $A \cap B$ = $A \setminus (A \setminus B)$, two subtractions.

The re-admission test: any construct enters as compression (above) or as a new axiom in this floor -- never a special case. The five constructors are the axioms; final segment and product are the two that earned admission by refusing to compress, and everything above compresses into the five.

## North-star

| Expression | Denotes |
| --- | --- |
| `{a,b,c}` | a, b, c |
| `{a..z}` | a, b, ..., z  (26 entries) |
| `{{cat,feline}}` | one entry, faces `cat` and `feline` |
| `{a..z, !{a,e,i,o,u}}` | 21 consonants  (difference = subtraction) |
| `{a..}` | a, b, c, ...  (order type $\omega$) |
| `{cat}{dog}` = `{catdog}` | catdog  (finite adjacency, compression) |
| `{a,ab}{b,c}` | ab, ac, abb, abc  (values 0-3) |
| `{a,ab}{c,bc}` | ac, abc, abbc  (`(ab,c)` re-spells `abc` at value 2, drops) |
| `{a..}{b}` | ab, bb, cb, ...  (order type $\omega$; not a spelling interval) |
| `{b,c}{a..}` | ba, bb, ...; ca, cb, ...  (order type $\omega \cdot 2$) |
| `{b}{a..}{b}{a..}` | baba, babb, ...; bbba, bbbb, ...  (order type $\omega^2$; seams collide, yet the type survives) |
| `{a..}{a..}` | aa, ab, ...; ba, bb, ...  (order type $\omega \cdot k$, not $\omega^2$: cofinite factors collide) |
| `{a,!{a}}` | {}  (empty universe) |
| `{z..a}` | {}  (reversed range) |
