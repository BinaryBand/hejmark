# Body-recursive within-body order -- design

Design note for the third `docs/.TODO.md` deferral: replace the sanctioned within-body approximation (spelling order) with an order that recurses into each constructor's own structure. This is the upstream primitive the rest of `L1/Bridge/` is framed onto (`entrySpellLt` feeds `entriesType`, `entryLt`, `prodLt`, `unionLt`, and every row), so it lands additively first and the existing modules migrate onto it one at a time -- strangler-fig, single tree, every intermediate build green.

## What changes and what does not

The carrier is unchanged: `Entries n := Subtype (denotes n)`. Same objects, same membership, same denotation (`denotes`, `spells`, `stage` are untouched). Only the order `<` on those entries changes -- from raw shortlex to a body-recursive tiebreak. So this is a `L1/Bridge/` change; nothing in `L1/Membership/` or `L1/Order/` moves.

## Core trick: rank into `Ordinal`, so well-orderedness reduces to injectivity

The existing files prove `IsWellOrder` by building a `RelEmbedding` into a `Prod.Lex` of known well-orders. For a *recursive* order the embedding target is itself recursive and dependent on which sub-body owns the entry, which is awkward to write. Instead, define a rank function into the single non-dependent type `Ordinal`:

```
entryRank n : Entries n -> Ordinal          -- structural recursion on the syntax
entryRecLt n a b := entryRank n a < entryRank n b
```

Then the well-order proof decomposes into three pieces, two of them free:

- well-founded: `InvImage.wf` of `<` on `Ordinal` -- free, no hypotheses.
- transitive: transitivity of `<` on `Ordinal`, pulled back -- free.
- trichotomous / total: holds iff `entryRank n` is **injective** on `Entries n`.

So the entire novelty of the well-order proof collapses to one lemma: `entryRank n` is injective (distinct spellings get distinct ranks). That is the single load-bearing obligation, provable by structural induction on the node. This is the main de-risking result of the pressure-test.

## The recursion, per constructor

Leaves are where spelling order is already exactly right; the reordering constructors compose sub-ranks into disjoint ordinal intervals so that injectivity is inherited.

```
-- leaf: range / face / final -- no reordering. Rank = shortlex position.
entryRank (leaf) s = typein (entrySpellLt leaf) s          -- ordinal rank in shortlex

-- fold inner -- entries are the inner language; recurse.
entryRank (fold inner) s = entryRank inner (s as inner-entry)

-- union (cons m rest) -- body-major with first-owner collision.
--   owned by m  (denotes (nsingle m) s):   entryRank (nsingle m) s
--   else (owned by rest):                  boundOf (nsingle m) + entryRank rest' s
--   where rest' is rest's entries minus those m already claims.

-- product (prod fs) -- positional / mixed radix over the factors' ranks,
--   entry owned by its least split (collision ownership, already settled for
--   the binary case in Product.lean's `leastSplit`):
--   entryRank = sum_i  entryRank(factor_i)(piece_i) * weightOf(later factors)

-- closure (binder) -- stage-major:
--   entryRank = stageOffset(firstStage s) + withinStageRank s
--   withinStageRank recurses into the body's structure (the hard spot, below).

-- sub inner -- adds no entries; contributes no rank of its own, only filters.
```

### Breaking the rank/offset circularity

Union's second-block offset and product's factor weights are *order types of sub-orders* -- but the sub-order is the one being defined, so rank and "type of this node's order" are mutually dependent. Break it by defining the pair together in one structural recursion:

```
entryRank  n : Entries n -> Ordinal
entryBound n : Ordinal                       -- the offset/weight this node contributes
  with the invariant  forall e, entryRank n e < entryBound n
```

`entryBound` is computed by the same recursion (union: sum of members' bounds over the collision-disjoint claims; product: product of factor bounds; fold: inner's bound; leaf: `entriesType leaf`). The invariant `entryRank n e < entryBound n` is proved alongside injectivity and is exactly what makes cross-block ranks disjoint.

## Why injectivity composes

Each reordering constructor lands its sub-ranks in disjoint ordinal intervals, so distinctness is inherited without re-examining spellings:

- union: first-block ranks are `< entryBound (nsingle m)`; second-block ranks are `>= entryBound (nsingle m)`. Cross-block distinct automatically; within-block distinct by the sub-injectivity IH. First-owner ownership makes the m-vs-rest choice a function of the spelling, so no entry is ranked twice.
- product: mixed radix `a * W + b` with `b < W` (the weight) is injective in `(a, b)` -- the ordinal `Ordinal.div_add_mod` fact -- and the least split is unique (`Product.leastSplit`, to be generalized n-ary), so the digit tuple is a function of the spelling.
- fold: injective because `entryRank inner` is, by IH.
- leaf: `typein` of a well-order is injective by construction.

## The one genuinely hard spot: closure within-stage

Stage-major ordering is settled (`firstStage` off the real `stage` ladder, already in `Entries.lean`). What is *not* settled is the order **within** a single stage: a closure's stage-`k` entries are body-applied-to-earlier-stages, a product-like shape whose faithful order recurses through both the body and the stage structure. This is the deepest sub-case and the real design risk.

Recommended staging: land leaf + union + product + fold on `entryRecLt` first, and keep the closure's within-stage order at shortlex for the first increment (identical to what `entryLt` already does, and already faithful at *stage* granularity -- the demotion-row theorems in `Entries.lean` are proved at exactly that resolution). Promote the within-stage order to body-recursive as a dedicated follow-up once the non-binder cases are proven. This keeps every increment green and isolates the risk.

## Anti-divergence bridge lemma

Mirroring `shortlexLt_iff_fshortlex`, prove that on any node with no reordering constructor -- `range` / `face` / `final`, and unions/products thereof where body order already equals spelling order -- `entryRecLt n = entrySpellLt n`. This certifies the new order cannot silently disagree with the old one where they should coincide, and it is what makes each migration step safe: a module moves from `entrySpellLt` to `entryRecLt` and the bridge lemma discharges the rows where nothing was supposed to change.

## Migration order (strangler-fig)

1. Add `RecOrder.lean` with `entryRank` / `entryBound` / `entryRecLt` and the free instances. Not yet imported by `L1.lean`.
2. Prove injectivity + the bound invariant -> `IsWellOrder (entryRecLt n)`, for leaf + union + product + fold.
3. Prove the leaf agreement bridge lemma. Import `RecOrder.lean` into `L1.lean`; gate stays green.
4. Closure within-stage body-recursion (own increment).
5. Migrate `entriesType` -> `prodLt` -> `unionLt` -> `Rows` onto `entryRecLt`, each a green build, deleting each approximation once its replacement is proved.
