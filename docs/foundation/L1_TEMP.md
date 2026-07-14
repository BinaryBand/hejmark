# Himark L1 -- Mathematical Floor (denotation)

The axiomatic floor: the one object, the constructors that build it, and the theorems they force. L1 fixes which universes *exist* and how they compose. Using a universe against text -- matching, query, capture -- is L1.5. Nothing here rejects or interprets.

## The object

- Face -- a spelling naming an entry; one entry may wear several (a fold), ordered by declaration and indexed from 0; the index-0 face is canonical.
- Entry -- one member of an alphabet.
- Alphabet -- a well-ordered set of entries, ordered by declaration. Virtual: denoted, never materialized, possibly infinite.
- Spelling order -- shortlex over spellings (shorter first, ties by code point). A well-order of type $\omega$; the order every cut cuts.
- Universe -- *the object*: a pointed alphabet `<alphabet, value, face>` -- a virtual list paired with one position. `value` picks the entry: an ordinal below $\omega^\omega$ -- a natural for a flat alphabet, a mixed-radix vector over a product's factors (positional value, below). `face` picks the spelling: an ordinal index into that entry's faces, **resting at 0** (the canonical face) and non-zero only for a folded entry hit by a later spelling. Together `<value, face>` is the **capture**, carried at the floor -- structural, like congruence by depth, not an add-on above. A written universe leaves `value` free to range over the list; matching binds `value` to one entry and `face` to the spelling that hit (L1.5). `face` never changes the denotation -- every face names the same member -- which is why it has a canonical rest where `value` ranges.
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

- Positional value -- a tuple $p_0 \ldots p_{k-1}$ over factor order types $b_i$ sits at $\sum_i \mathrm{value}(p_i) \cdot (b_{i+1} \cdots b_{k-1})$: mixed radix, most-significant-first. The face axis composes identically over per-entry face counts. Finite factors give naturals; an infinite factor gives an ordinal -- Cantor normal form at base $\omega$, weight on the left, multiplication no longer commuting. An entry's rank equals its value only when the factors are uniquely decodable: concatenation is not injective (`{a,ab}{c,bc}` spells `abc` twice, and the union no-op keeps the lower-valued one), yet the denotation stays faithful either way.
- Bounded transfinitude -- order types are the ordinals below $\omega^\omega$, closed under every constructor (product multiplies, union adds, fold and subtraction shrink) and never reaching it, since every expression is finite. Union alone gives $\omega$ plus a finite tail; product reaches higher -- `{b,c}{a..}` is $\omega \cdot 2$, `{a..}{a..}` is $\omega^2$. (The matching consequence, decidability over finite text, is L1.5.)
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
| `{a..}{a..}` | aa, ab, ...; ba, bb, ...  (order type $\omega^2$) |
| `{a,!{a}}` | {}  (empty universe) |
| `{z..a}` | {}  (reversed range) |
