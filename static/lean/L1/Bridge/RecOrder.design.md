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

-- fold inner -- branch on whether the inner universe binds (see the
--   correction below). Only fold-of-a-NON-binder is inner's language:
--     bindsb inner = false:  entryRank inner (s as inner-entry), modulo the
--                            fold-to-unit empty face when inner is empty.
--     bindsb inner = true:   this member IS a closure -- defer to the closure
--                            fallback, `typein (entryLt (nsingle (fold inner)))`.

-- union (cons m rest) -- body-major with first-owner collision.
--   owned by m  (denotes (nsingle m) s):   entryRank (nsingle m) s
--   else (owned by rest):                  boundOf (nsingle m) + entryRank rest' s
--   where rest' is rest's entries minus those m already claims.

-- product (prod fs) -- positional / mixed radix over the factors' ranks,
--   entry owned by its least split (collision ownership, already settled for
--   the binary case in Product.lean's `leastSplit`):
--   entryRank = sum_i  entryRank(factor_i)(piece_i) * weightOf(later factors)

-- closure (any binder node, AND a fold-of-binder) -- deferred stage-major:
--   entryRank = typein (entryLt node) s
--   `entryLt` (stage-major, shortlex within a stage) is already a proven well
--   order in Entries.lean; its `typein` is an injective rank for free. The
--   within-stage body-recursion is the follow-up increment that replaces this
--   fallback; until then no closure case is stubbed.

-- sub inner -- adds no entries; contributes no rank of its own, only filters.
```

### Correction: fold-of-a-binder is a hidden closure

`nsingle (fold inner)` is always classified a non-binder (`freeAmpb (.fold _) = false` -- the fold's own braces are the innermost binder site, so a fold never contributes a *free* `&` to the node that contains it). But `spells (.fold inner)` (Semantics.lean) reads `if bindsb inner then (exists k, stage inner k s) else ...` -- so when the inner universe binds, the fold's denotation is the closure of inner, even though the node is non-binder. The recursion therefore branches on `bindsb inner` at each fold member, not on `bindsb node`, and the binder branch routes into the closure fallback above. This is the one place the "non-binder skeleton" leaks a closure, and missing it would have put a `stage`-semantics set under a leaf rank.

The upshot is a cleaner first increment: **every closure -- a top-level binder node and a fold-of-binder alike -- ranks by `typein (entryLt node)`**, so the body-recursion is confined to the genuine non-binder skeleton (union / product / leaf / fold-of-non-binder) and the deferred within-stage order is uniformly the existing, already-proven `entryLt`. No case is left as `sorry`.

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
- fold-of-non-binder: injective because `entryRank inner` is, by IH.
- closure (binder node, fold-of-binder): injective because `typein (entryLt node)` is (`typein` of a well order).
- leaf: `typein` of a well-order is injective by construction.

## The one genuinely hard spot: closure within-stage

Stage-major ordering is settled (`firstStage` off the real `stage` ladder, already in `Entries.lean`). What is *not* settled is the order **within** a single stage: a closure's stage-`k` entries are body-applied-to-earlier-stages, a product-like shape whose faithful order recurses through both the body and the stage structure. This is the deepest sub-case and the real design risk.

Staging (revised): the first increment ranks *every* closure -- a top-level binder node and a fold-of-binder alike -- by `typein (entryLt node)`, the existing stage-major/shortlex-within-stage well order. That order is already proven (Entries.lean) and already faithful at *stage* granularity (the demotion-row theorems are at exactly that resolution), and its `typein` is an injective rank for free -- so the closure case is *complete*, not stubbed, from increment one. The body-recursion runs only on the genuine non-binder skeleton (leaf / union / product / fold-of-non-binder). Promoting the within-stage order from this `entryLt` fallback to a body-recursive order is the dedicated follow-up increment; until it lands, `entryRecLt` and `entryLt` agree on every closure by construction, so nothing regresses.

## Anti-divergence bridge lemma

Mirroring `shortlexLt_iff_fshortlex`, prove that on any node with no reordering constructor -- `range` / `face` / `final`, and unions/products thereof where body order already equals spelling order -- `entryRecLt n = entrySpellLt n`. This certifies the new order cannot silently disagree with the old one where they should coincide, and it is what makes each migration step safe: a module moves from `entrySpellLt` to `entryRecLt` and the bridge lemma discharges the rows where nothing was supposed to change.

## Migration order (strangler-fig)

1. [landed] Add `RecOrder.lean` with `entryRank` / `entryBound` / `entryRecLt` and the free instances. Not yet imported by `L1.lean`.
2. [landed] Prove injectivity + the bound invariant -> `IsWellOrder (entryRecLt n)`, for leaf + union + product + fold (`entryRecLt_isWellOrder`, over the deep subtraction-free skeleton `nSubfree`).
3. [landed] Prove the leaf agreement bridge lemma (`entryRecLt_leaf`, specialized to `entryRecLt_face` / `_range` / `_final`). Import `RecOrder.lean` into `L1.lean`; gate stays green (`entryRecLt_isWellOrder` and `entryRecLt_face` added to `HEADLINE_THEOREMS`, axioms clean).
4. Closure within-stage body-recursion (own increment).
5. Migrate `entriesType` -> `prodLt` -> `unionLt` -> `Rows` onto `entryRecLt`, each a green build, deleting each approximation once its replacement is proved.
