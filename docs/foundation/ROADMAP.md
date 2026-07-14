# Himark Roadmap

## Layer 1 -- Mathematical Floor (denotation)

- The object -- the pointed alphabet `<alphabet, value, face>`; value and face are ordinals below $\omega^\omega$.
- Constructor floor -- union, subtraction, fold, final segment, product (five total constructors).
- Theorems -- positional value, bounded transfinitude (order type $< \omega^\omega$), compression-not-capability; the value and face axes share one mixed-radix shape.

## Layer 1.5 -- Language Surface (interpretation)

- Matching -- query and capture, text membership, maximal munch, decidability.
- Transformation primitives -- set filtering, product/exponent, aggregate-by-union-or-fold, and the modifier pipeline that hosts them.
- Registers -- L1's positional index made addressable.

> Finish Line: When L1.5's primitives suffice to define `where` and `pad` in L2 -- algebra alone, no built-in named modifiers.

## Layer 2 -- In-Language Rewrites And Variables

- Variables -- (`uni foo = {...}`)
- Functions -- (`{...}[bar ... baz ...]`); where `where` and `pad` are defined, over L1.5's primitives.

| Expression | Denotes |
| --- | --- |
| `{0..9}[where 8..12]` | 8, 9, 10, 11, 12 |
| `{a..z}[where aa..cc]` | a, b, ..., z, ba, ..., cc (55 entries; aa = a = 0) |
| `{8,9,10,11,12}[pad 2]` | 88, 89, 10, 11, 12 |
| `{0..9}[where 8..12 pad 1..2]` | {8,08}, {9,09}, 10, 11, 12 |

## Layer 3 -- Linting

- Compiler Errors
- Formal Formatting
