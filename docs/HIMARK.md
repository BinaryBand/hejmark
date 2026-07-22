# Himark Cheat Sheet

<!-- cspell:words upto padfree zfold noncharacters sEEd pttrn -->

A quick reference for writing `.hmk` source. Normative definitions live in `docs/foundation/` (`L1.md`, `L1_5.md`, `L2.md`, `L3.md`); this page is a derived index over them, not a fifth spec -- when in doubt, the foundation docs win.

## The object

A **universe** is a pointed alphabet: a virtual list of **entries**, each wearing one or more **faces** (spellings), plus a pointer at one entry and one face. `<value, face>` -- entry index and face index -- is the **capture**, carried at the floor. Matching binds `value`; `face` names which spelling hit.

## The six constructors (L1, denotation -- nothing here rejects)

| Syntax            | Name          | Denotes                                                                                   |
| ----------------- | ------------- | ----------------------------------------------------------------------------------------- |
| `{a,b,c}`         | Union         | entries in order, duplicates skipped (idempotent, not commutative)                        |
| `!{...}`          | Subtraction   | strip the spelling(s) claimed by the operand; an entry with no face left drops            |
| `{a,b}` as member | Fold          | quotient several faces onto **one** entry; `{{}}` is the unit (one entry, the empty face) |
| `{a..}`           | Final segment | every spelling from `a` on, in shortlex order (unary, no upper bound)                     |
| `{cat}{dog}`      | Product       | tuples, spelled by concatenation, ordered by mixed-radix positional value                 |
| `&`               | Closure       | self-reference; denotes the closure at $\omega$ of its body                               |

Empty universe `{}` / `{a,!{a}}`: no entries, legal. Unit `{{}}`: one entry, one face (the empty spelling) -- the product identity, never a query match (zero-width never matches).

## Compression (notation, no added power)

| Syntax       | Expands to                                                           |
| ------------ | -------------------------------------------------------------------- |
| `{a..z}`     | `{a.., !{s..}}` (`s` = shortlex successor of `z`)                    |
| `{cat}{dog}` | `{catdog}` (finite adjacency)                                        |
| `A^n`        | `A` written adjacent `n` times (iterated product; `A^0` is the unit) |
| `A \ B`      | `{...A..., !{...B...}}`                                              |
| `A ∩ B`      | `A \ (A \ B)`                                                        |
| `{w..}`      | `{{{}}, &C} \ {predecessors of w}` (`C` = code-point set)            |

## Names and definitions (L1.5)

```text
uni name = {...}          // declaration; splices entry-wise wherever a universe stands
@name                     // reference; sigil keeps a name from reading as a spelling
name params := body       // definition; applied via the pipeline
A[f x g y]                // modifier pipeline: stages left to right, each result feeds the next
```

- Acyclic: a name (or definition) can't reach itself through its own declaration. `&` is the only self-reference, and it lives on the floor.
- `_` is the pipeline operand token -- bound only at application; a definition invoked bare inside another body gets no `_`.
- **Head**: registers read the pipeline *head*, not the current stage -- `{0..9}[where 8..12 pad 1..2]` fills with `0` because the head is `{0..9}`.
- Numeral parameters canonicalize in the head radix (`aa` binds as `a`); a lone numeral argument binds a pair parameter as `n..n`.

## Registers (the closed inventory -- four tokens, two addressed families)

| Register  | Reads                                                             | Where it's legal                               |
| --------- | ----------------------------------------------------------------- | ---------------------------------------------- |
| `@`       | the pipeline head, as a universe                                  | definition bodies                              |
| `@lo..hi` | the head's value line, cut to values `lo..hi` (`@0` = zero entry) | definition bodies                              |
| `$`       | the hit, as it hit (bound entry, bound face)                      | templates                                      |
| `$0`      | the hit's canonical face (face 0)                                 | templates                                      |
| `$1..$n`  | factor `k` of the hit, 1-based, spelled as it hit                 | templates, and patterns (back-refs, see below) |

`where lo..hi` is the pipeline spelling of `@lo..hi` (a **value** cut, radix-general -- not a spelling range, which only agrees with value order when digits are single code points in code-point order).

## Matching

- **Query** = a universe run against text; matches one entry, any face.
- **Longest-first** (maximal munch): a longer face beats a prefix of it. Declaration order never selects.
- **Zero-width excluded**: the unit's empty face never matches.
- **Back-references**: `{$k}` as a factor, or `$k` as a pipeline argument (`where 0..$2`), reads factor `k` of the *same* query -- strictly to its left (matcher binds left to right; a read never crosses a declaration).
- **Scope**: decidable only where every closure body is *guarded* (an `&`-free factor with no empty face) -- closure-free queries are always in scope. Unguarded/negative bodies still denote but only semi-settle; matching them is refused (L2), not a denotation failure.

## Emit -- statements (L1.5)

A statement is a chain of steps joined by `=>`:

```text
query => template => query => template ...
```

- **Query step** refines: tiles the incoming branch, one sub-branch per match; no match stops the branch (the guard reading).
- **Template step** constructs: quoted `"..."`, literal text plus `{{...}}` interpolation sites (each one capture read: `$`, `$0`, `$k`, or `{{@name}}` for a sentinel). Commits over the branch's span.
- A leading query branches into the statement's target; a leading template is detached (computes off-document; the document never changes).
- **Contraction**: `query <=>[@m] template` -- re-run the pass until nothing rewrites. `@m` (a plain `uni`, declared on the arrow) is the measure: each pass's document must sit strictly earlier in `@m`'s entry order than before, or the host refuses. Entry order is a well-order, so no infinite descent -- passes settle.

| Statement                        | Against     | Yields                                                 |
| -------------------------------- | ----------- | ------------------------------------------------------ |
| `{{cat,feline}} => "{{$0}}"`     | `my feline` | `my cat`                                               |
| `{a,e,i,o,u} => ""`              | `pattern`   | `pttrn`                                                |
| `{@spellings} => "<b>{{$}}</b>"` | `abc`       | `<b>abc</b>`                                           |
| `{a} => {b}`                     | `banana`    | `banana` (guard: no `b` inside `a`)                    |
| `"seed" => {e} => "E"`           | anything    | unchanged (leading template is detached)               |
| `{a,ab}{c,bc} => "{{$2}}"`       | `abc`       | `bc` (collision gave `abc` to value 1, split `(a,bc)`) |
| `{ba} <=>[@spellings] "ab"`      | `bbaa`      | `aabb` (3 passes)                                      |

## Sentinels

```text
sentinel start
sentinel end
```

Declares a name denoting one entry, one face: a host-allocated noncharacter (U+FDD0 up). Invisible to `@C` (subtracted out), so nothing but the name matches it -- collision with real content is unrepresentable. Never let one survive to the document boundary; clean up explicitly:

```text
{@start,@end} => ""
```

## The std (L3, `core/compiler/std.py`)

```text
uni hex         = {0..9,a..f}                                 -- the hex radix
uni spellings   = {{{}}, &@C}                                 -- every spelling, in shortlex
fill            := {{{}, @0}}                                 -- one entry, faced empty and zero
nonzero         := {@, !{@0}}
numerals        := {@0, {@nonzero, &@}}                       -- the value line of the head radix
shorter w       := {@spellings, !{@C^w @spellings}}           -- widths below w
upto w          := {@shorter w, @C^w}                         -- widths at most w
longer w        := {@spellings, !{@upto w}}                   -- widths above w
where lo..hi    := {@lo..hi}                                  -- the value line cut by value
pad w..w'       := {@fill^{w'} _, !{@shorter w}, !{@longer w'}}
zeros           := {{{}}, &@0}                                -- the zero-runs of the head, empty included
zfold           := {{@zeros}}                                 -- folded: one entry wearing every zero-run
padfree         := {@zfold _}                                 -- every entry at every zero-padding
```

| Expression                     | Denotes                             |
| ------------------------------ | ----------------------------------- |
| `{0..9}[where 8..12]`          | 8, 9, 10, 11, 12                    |
| `{a..z}[where aa..cc]`         | a, ..., z, ba, ..., cc (55 entries) |
| `{8,9,10,11,12}[pad 2]`        | 88, 89, 10, 11, 12                  |
| `{0..9}[where 8..12 pad 1..2]` | {8,08}, {9,09}, 10, 11, 12          |

`pad` caps widths (its `w'` feeds an exponent); `padfree` is the uncapped version -- matching one stays in scope (membership decides), but a *canonical-face* read of one does not (infinitely many faces per entry).

## Layers, in one line each

| Layer | Doc       | Question                                                                              |
| ----- | --------- | ------------------------------------------------------------------------------------- |
| L1    | `L1.md`   | What universes exist? (denotation, cemented)                                          |
| L1.5  | `L1_5.md` | What can be written? (surface, admission = expands into the six constructors)         |
| L2    | `L2.md`   | What can be *run*? (bounded reads, decidable matching, termination, boundary hygiene) |
| L3    | `L3.md`   | What's in the box? (std library, pure L1.5 declarations)                              |

## Known bounded/refused operations (L2)

These raise a diagnostic past a host budget rather than hang or guess:

- `$0` / an ambiguous factor split (`$1..$n`, or a back-reference split) -- streams entries in value order to find the claimant.
- `@lo..hi` / `where` over an unbounded radix, or past the budget.
- Matching against an unguarded or negative closure body -- refused outright, not just budgeted.
- A `<=>` pass that fails to strictly shrink its declared measure.
- A noncharacter (sentinel) at either document boundary.

## CLI

```bash
hejmark find query.hmk target.txt     # scan; one line per match, then a count
hejmark run script.hmk target.txt     # run a whole script, print the spliced document
hejmark parse-file path.hmk           # dump a parse tree (debugging)
hejmark emit-json query.hmk           # lower a query to floor-AST JSON (another engine's `find` hand-off)
hejmark emit-fragments a.hmk b.hmk    # lower several queries at once, under their declared names
hejmark emit-program script.hmk       # lower a whole script to Program JSON (the `run` hand-off)
```

## North star (bubble sort, `static/examples/demos/bubble-sort.hmk`)

Sentinels mask each line, factor reads and a back-reference spell an adjacent out-of-order pair by value (any padding, any magnitude), and a contracting statement iterates the swap under a measure built from `numerals padfree` -- so the value line, not the spelling, decides sort order:

```text
sentinel start
sentinel end

uni c      = {@C, !{\n}}
uni line   = {@c, &@c}
uni d      = {0..9}
uni digits = {@d, &@d}
uni value  = {0..9}[numerals padfree]
uni list   = {@value, &{\,}{@value}}
uni sorted = {{@start}{@list}{@end}, &{\n}{@start}{@list}{@end}}

{@line} => "{{@start}}{{$}}{{@end}}"
{@start,\,}{@digits}{\,}{{0..9}[where 0..$2 padfree], !{{0..9}[where $2 padfree]}}{@end,\,} <=>[@sorted] "{{$1}}{{$4}},{{$2}}{{$5}}"
{@start,@end} => ""
```
