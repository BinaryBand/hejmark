# Himark Foundation -- The Root Model

**Status:** Normative core (spec-first; see [TODO.md](TODO.md)) | **Governs:** [HMK.md](HMK.md), [ALGEBRA.md](ALGEBRA.md), [ENGINE.md](ENGINE.md)

This document is the axiomatic floor of the language. Every construct, present or future, is expressible as a constructor over the one object defined here, or enters as a new axiom recorded here; nothing may redefine the object itself.

## Vocabulary and the object

The foundation imports its substrate from standard mathematics, in standard senses no law below may redefine. Every term below is a universe object wearing a Himark role; terms are defined once, here, and every governed document uses them in exactly these senses.

- A **face** is a spelling in the role of naming one entry. **Fold** is the quotient constructor that lets several faces name one entry -- not the fold of functional programming: it collapses names into an identity, reducing nothing.
- A **aphabet** -- is a finite ordered set of entries, ordered by declaration; the word is set theory's, narrowed. It is virtual: denoted, never materialized.
- An **entry** is an individual member of an alphabet.
- An **universe** *the object*, the only one the language has. A pointed alphabet, `<universe, value, face>` -- the universe with one distinguished position, no field nullable.
- A **query** is a universe in the match role, used against text. It matches exactly one entry, by any face; against the empty universe it matches nothing.
- A **capture** a universe in the already matched role. It is a derived value, never stored: an operand's universe and position name it exactly, so no operand carries a text field.

## The constructor floor

Three constructors, all total, build every universe:

- **Union** (`,`) appends an entry not yet present; a member whose spelling is already claimed contributes nothing (a no-op). Union is idempotent and associative, not commutative.
- **Subtraction** (`!{...}`) removes a present entry, and the set renumbers; a member naming no entry removes nothing (a no-op). Union and subtraction are dual: each is total by the same no-op rule over the same membership test.
- **Fold** (nesting as member) quotients spellings into one entry; a face whose spelling is already claimed drops from the fold (`{a,{a,A}}` holds two entries, the second spelled only `A`). Depth below the member flattens -- an entry is its flattened face sequence, claims applied in source order: `{a,{b,{c,C}}}` equals `{a,{b,c,C}}`.

The constructors reach the **empty universe** (`{a,!{a}}`). It is legal, and a query denoting it matches nothing; emptiness is meaningless, not invalid, and meaningfulness stays an L2 concern.

The source and AST are faithful -- nothing is rejected or rewritten at parse time. Normalization is the constructor semantics itself, applied wherever the universe is read, the same place subtraction has always resolved.

## Theorems, not axioms

These follow from the object and are never postulated separately:

- **Positional value.** The product (adjacency) of universes, ordered lexicographically most-significant-first, places the string $p_0 \ldots p_{k-1}$ over a base of cardinality $b$ at index $\sum_i \mathrm{value}(p_i) \cdot b^{k-1-i}$. The value formula is the product order, not an axiom. The face axis composes the same way: a product entry's faces are its positions' faces in order, mixed radix over per-entry face counts, so both axes of a position are closed under product.
- **Compression, not capability.** Ranges (`{a..z}`), adjacency (`{cat}{dog}` = `{catdog}`), products, and splice (a spread form contributing a named universe's entries member by member) are notation for unions spellable by hand. They compress the spelling; they add nothing to what a query can denote. Fold is not on this list: no arrangement of flat members makes two spellings share one value, which is why fold is a constructor and splice is not.
The re-admission test for any stripped or future construct: it enters either as **compression** (notation for a universe the floor already denotes) or as a **new axiom recorded below** -- never as a special case.

## Scope

Match strategy (leftmost scan, greedy order, canonical parse for non-uniquely-decodable entry sets), capture numbering (how a match decomposes into numbered spans -- derivation metadata, not denotation), the emit surface (templates, moustaches, filters -- notation over the emit floor), and physical representation (engine-local; see [ENGINE.md](ENGINE.md)) are separate layers. Each must respect the object; none may extend it.
