# Himark L1 -- Mathematical Floor (denotation)

The axiomatic floor: the one object, the constructors that build it, and the theorems they force. L1 fixes which universes *exist* and how they compose. Using a universe against text -- matching, query, capture -- is L1.5. Nothing here rejects or interprets.

## The object

- Face -- a spelling naming an entry; one entry may wear several (a fold), ordered by declaration and indexed from 0; the index-0 face is canonical.
- Entry -- one member of an alphabet.
- Alphabet -- a well-ordered set of entries, ordered by declaration. Virtual: denoted, never materialized, possibly infinite.
- Spelling order -- shortlex over spellings (shorter first, ties by code point). The code-point set is finite, so this is a well-order of type $\omega$; the order every cut cuts.
- Universe -- *the object*: a pointed alphabet `<alphabet, value, face>`, a virtual list paired with one position. `value` picks the entry: an ordinal below $\omega^\omega$ -- a natural for a flat alphabet, mixed radix over a product's factors (positional value, below). `face` picks the spelling: an index into that entry's faces, **resting at 0** (the canonical face), non-zero only when a fold's later spelling hit. The pair `<value, face>` is the **capture**, carried at the floor, not bolted on above. A written universe leaves `value` free to range; matching (L1.5) binds `value` to one entry and `face` to the spelling that hit. `face` never changes the denotation -- every face names the same member -- so it rests where `value` ranges.
- Empty universe -- the empty alphabet (`{a,!{a}}`, or the empty member list `{}`), order type $0$: no entry, so no position to bind -- the object's only nullability. Legal and denotable; emptiness is meaningless, not invalid.
- Unit universe -- fold over the empty alphabet (`{{}}`), order type $1$: one entry wearing exactly one face, the **empty spelling**. Not an axiom -- fold's boundary case, forced by its totality: a fold yields one entry, each face of that entry is the concatenation of the characters declared for it, and the concatenation of no characters is the empty spelling. Zero *declared* faces is one empty face, never zero faces: a factor with no face would zero the product's face axis (mixed radix over per-entry face counts) and the identity below would fail on that axis while holding on the value axis. It is the only source of the empty spelling (shortlex's least element, unwritable as a face token), it is the product's identity, and no query matches on it -- L1.5's matcher never accepts a zero-width span. Two braces apart from the empty universe and the exact opposite of it: `{}` has no entry, `{{}}` has an entry with nothing to say.

## The constructors

Five, all total; they build every universe.

- Union `,` -- append a universe's entries, in its order, skipping any already present; a lone spelling is the singleton case. Idempotent, associative, not commutative.
- Subtraction `!{...}` -- remove a universe's entries where present and renumber; an absent entry is a no-op. Dual to union over the same membership test.
- Fold `{...}` as member -- quotient several faces onto one entry; a claimed spelling drops. Depth flattens: `{a,{b,{c,C}}}` = `{a,{b,c,C}}`, and a nested `{}` flattens to the unit's one face, the empty spelling -- which is what gives `{{{},0}}` its two faces, `` and `0`. Total: over the empty alphabet it yields the unit.
- Final segment `{a..}` -- every spelling from `a` onward in spelling order, by the union rule. Unary: one cut, no right endpoint, no infinity token. Unboundedness is the missing second cut.
- Product `{cat}{dog}` -- entries are tuples, one per factor, spelled by concatenation, ordered by positional value. Total (empty factor gives the empty universe). Identity: the unit -- a factor of order type $1$ wearing one empty face contributes no weight on the value axis and a factor of $1$ on the face axis, so `{{}}A` = `A` on both, and exponent `A^n` is well-formed down to `A^0`. Finite factors flatten (compression); an infinite factor does not, so product is a constructor, not notation.

The universe operand on union and subtraction is axiomatic: an entry-wise step adds or removes finitely many entries, while `{a.., !{ {a..}{b}{a..} }}` -- every spelling with no interior `b`-seam -- needs infinitely many removals and is unreachable by any finite iteration of entry-wise steps.

## The theorems

Forced by the object, never postulated.

- Positional value -- a tuple $p_0 \ldots p_{k-1}$ over factor order types $b_i$ sits at $\sum_i W_i \cdot \mathrm{value}(p_i)$, summed most-significant term first with weight $W_i = b_{k-1} \cdot b_{k-2} \cdots b_{i+1}$ on the left of its digit: mixed radix. The face axis composes identically over per-entry face counts, and it collides by the same no-op. One rule settles every collision, within an entry and across entries alike: a spelling is claimed by the least `<value, face>` address that spells it -- value first, face index to break the tie -- and every later claimant drops it, exactly as fold drops a claimed spelling. Within one entry that is `Z^2` building `0` from both a left and a right fill: same value, so the lower face index keeps it. Across two entries it is the union no-op: `{a,ab}{c,bc}` spells `abc` from both `(a,bc)` at value 1 and `(ab,c)` at value 2, and the lower value keeps it. The cross-axis case is the same rule and needs no extra clause, only the warning that a *canonical* face can be the one that drops: in `{{{},0}}{0,00}` the value-0 entry wears `0` and `00`, the value-1 entry wears `00` and `000`, and the claimants to `00` are `<0,1>` and `<1,0>` -- value dominates, so the value-1 entry loses its index-0 face and is left canonically spelled `000`. Surviving faces renumber, so "canonical" stays "index 0" and never names a dropped spelling; an entry that loses every face has no spelling left to be matched by and drops with them. Finite factors give naturals, where the order of multiplication is invisible; an infinite factor gives an ordinal -- Cantor normal form at base $\omega$ -- where it is load-bearing: $n \cdot \omega = \omega$ collapses any digit placed on the left. Rank equals value only when the factors decode uniquely: concatenation is not injective (`{a,ab}{c,bc}` spells `abc` twice; the union no-op keeps the lower value), and membership survives the drop where rank and order type need not.
- Bounded transfinitude -- order types are the ordinals below $\omega^\omega$: closed under every constructor (union adds, subtraction shrinks, fold collapses to exactly one entry, product multiplies at most, and collision only shrinks) and never reaching the bound, since every expression is finite. Union alone gives $\omega$ plus a finite tail; product climbs -- `{b,c}{a..}` is $\omega \cdot 2$, `{b}{a..}{b}{a..}` is $\omega^2$. Collision alone does not decide the type: each drop keeps the least-valued split, and the surviving least splits do. In `{b}{a..}{b}{a..}` the seams collide (`babba` is both `b|a|b|ba` and `b|ab|b|a`), yet every pair with a `b`-free first segment is its own least split -- infinitely many full $\omega$-blocks survive, cofinally, so $\omega^2$ stands. In `{a..}{a..}` the least split pins the prefix to length at most 2, only finitely many blocks survive, and the type collapses to $\omega \cdot k$, $k$ finite. (The matching consequence, decidability over finite text, is L1.5.)
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
| `{{}}` | one entry, one face: the empty spelling  (unit; `{{}}{cat}` = `{cat}`) |
| `{{{},0}}` | one entry, faces `` and `0`  (the fill factor: fold of the unit with a spelling) |
| `{{{},0}}{{{},0}}` | one entry, faces ``, `0`, `00`  (`Z^2`; the two ways to spell `0` collide, the lower survives) |
| `{{{},0}}{0..9}` | 0, 1, ..., 9, each also faced `00`, `01`, ..., `09`  (values unchanged; a face axis, not an entry axis) |
| `{{{},0}}{0,00}` | one entry faced `0`, `00`; one faced `000`  (cross-axis collision: `00` is claimed by the lower value, so the higher entry loses its *canonical* face and renumbers) |
