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
- Decidability -- text is finite, so at any position only the finitely many faces no longer than the remaining text are candidates, whatever the order type above. (The matching half of L1's bounded transfinitude.)

## Registers

- Every entry's L1 `value` (and its face index) made addressable -- a handle on a matched position. A capture is a register read; nothing is stored.

## Transformation primitives

<!-- 
I gotta figure this one out.
filter = payload, arg
 -->

## The pipeline

- Form -- `<operand> [ <func> <arg>  <func> <arg>  ... ]`: a left-to-right chain of total universe-to-universe transformers.

## Finish line

> L1.5 is done when this surface suffices to define `where` and `pad` in L2 -- algebra alone, no built-in named modifiers.
