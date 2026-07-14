# Himark Foundation -- The Root Model

This document is the axiomatic floor of the language. Every construct, present or future, is expressible as a constructor over the one object defined here, or enters as a new axiom recorded here; nothing may redefine the object itself.

## Vocabulary and the object

Every term below is a universe object wearing a Himark role; terms are defined once, here, and every governed document uses them in exactly these senses.

- A **face** is a spelling in the role of naming one entry. **Fold** is the quotient constructor that lets several faces name one entry -- not the fold of functional programming: it collapses names into an identity, reducing nothing.
- An **alphabet** is a well-ordered set of entries, ordered by declaration; the word is set theory's, narrowed. It is virtual: denoted, never materialized.
- The **spelling order** is shortlex over spellings: shorter first, ties broken code point by code point. It is a well-order of type $\omega$ -- every spelling has finitely many predecessors and a successor -- and it is the one order every unbounded construct cuts.
- An **entry** is an individual member of an alphabet.
- An **universe** *the object*, the only one the language has. A pointed alphabet, `<universe, value, face>` -- the universe with one distinguished position, no field nullable.
- A **query** is a universe in the match role, used against text. It matches exactly one entry, by any face; against the empty universe it matches nothing.
- A **capture** a universe in the already matched role. It is a derived value, never stored: an operand's universe and position name it exactly, so no operand carries a text field.

## The constructor floor

Four constructors, all total, build every universe:

- **Union** (`,`) appends an entry not yet present; a member whose spelling is already claimed contributes nothing (a no-op). Union is idempotent and associative, not commutative.
- **Subtraction** (`!{...}`) removes a present entry, and the set renumbers; a member naming no entry removes nothing (a no-op). Union and subtraction are dual: each is total by the same no-op rule over the same membership test.
- **Fold** (nesting as member) quotients spellings into one entry; a face whose spelling is already claimed drops from the fold (`{a,{a,A}}` holds two entries, the second spelled only `A`). Depth below the member flattens -- an entry is its flattened face sequence, claims applied in source order: `{a,{b,{c,C}}}` equals `{a,{b,c,C}}`.
- **Final segment** (`{a..}`) contributes every spelling from `a` onward in spelling order, each by the union rule. It is unary: an interval has two endpoints, a final segment has one cut. There is no right-hand side -- elided, defaulted, or infinite -- and no infinity token exists in the language; unboundedness is the absence of a second cut, not the presence of a limit object. The other constructors need no amendment: subtracting a final segment truncates, and a fold over one is a single entry wearing unboundedly many faces -- an entry, not an exception.

The constructors reach the **empty universe** (`{a,!{a}}`). It is legal, and a query denoting it matches nothing; emptiness is meaningless, not invalid, and meaningfulness stays an L2 concern. A bounded range whose lower endpoint exceeds its upper (`{z..a}`) denotes the standard empty interval; emptiness and unboundedness never share a spelling.

The source and AST are faithful -- nothing is rejected or rewritten at parse time. Normalization is the constructor semantics itself, applied wherever the universe is read, the same place subtraction has always resolved.

## Theorems, not axioms

These follow from the object and are never postulated separately:

- **Positional value.** The product (adjacency) of universes, ordered lexicographically most-significant-first, places the string $p_0 \ldots p_{k-1}$ over a base of cardinality $b$ at index $\sum_i \mathrm{value}(p_i) \cdot b^{k-1-i}$. The value formula is the product order, not an axiom. The face axis composes the same way: a product entry's faces are its positions' faces in order, mixed radix over per-entry face counts, so both axes of a position are closed under product. Over an infinite universe the base is its order type, not a cardinal, and the sum is read in ordinal arithmetic with the base power on the left -- $\sum_i b^{k-1-i} \cdot \mathrm{value}(p_i)$, Cantor normal form when $b = \omega$; multiplication stops commuting, the theorem does not change. Finite universes keep the familiar naturals.
- **Bounded transfinitude.** The floor cannot outrun $\omega$: once a final segment enters, every later member contributes finitely many entries (each spelling below a cut has finitely many predecessors), so a universe's order type is at most $\omega$ plus a finite tail, never $\omega \cdot 2$. Matching stays decidable by the same fact read the other way: text is finite, so at any position only the finitely many faces no longer than the remaining text are candidates.
- **Compression, not capability.** Ranges (`{a..z}`), adjacency (`{cat}{dog}` = `{catdog}`), products, and splice (a spread form contributing a named universe's entries member by member) are notation for universes the floor already denotes. A bounded range is the difference of two final segments -- `{a..z}` is `{a..,!{s..}}` with `s` the successor of `z` in spelling order -- so ranges stay compression even with multi-spelling endpoints, and the interval is derived from the cut, never the reverse. They compress the spelling; they add nothing to what a query can denote. Fold and final segment are not on this list: no arrangement of flat members makes two spellings share one value, and no finite arrangement contributes unboundedly many entries -- which is why each is a constructor and splice is not.
The re-admission test for any stripped or future construct: it enters either as **compression** (notation for a universe the floor already denotes) or as a **new axiom recorded below** -- never as a special case. Final segment is the first construct admitted on the axiom side (recorded in the floor above); bounded ranges moved to the compression side in the same stroke.
