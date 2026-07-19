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
4. Closure within-stage body-recursion (own increment), itself sliced:
   - 4a. [landed] Stage-structure backbone (`RecOrder.stageOffset` / `stageRank`, `stageRank_injective` / `stageRank_isWellOrder`). Abstract over any within-stage rank: given `w e < W (st e)` and per-stage injectivity, the stage-major assembly (finite ladder offset `stageOffset` plus `w`) is an injective rank, hence a well order. The offset is a finite sum because `firstStage` is a `Nat`, so this is the union-block disjoint-interval argument run along the stage ladder -- to the ladder what `mixmul` is to the product. Additive, not yet fed by a real closure.
   - 4b. Within-stage body rank: thread an amp-rank parameter through the body recursion (generalize `mRank` / `nRank` / `fRank`, or a parallel body rank) so the `.amp` leaf ranks by a supplied earlier-stage rank instead of the `typein (entryLt (nsingle .amp))` fallback; prove faithful given a faithful amp-rank. This is the `hbound` / `hinj` (per stage) input to 4a. Itself sliced:
     - 4b-i. [landed] The within-stage membership inversions: the general-amp generalization of the `denotes_*` reinterpretation block (`walk_single_amp_false`, `walk_napp_iff`, `walk_fold_nonbinder`, `walk_prodNode_fsplit` / `walk_prodNode_node_split`). A stage-`k+1` body-spelling lives in `walk n (stage n k) False`, not in `denotes n = walk n the empty set False`, so the union / fold / product routings restate over an arbitrary amp-set; the proofs are the amp-general core the `denotes_*` versions already specialize (`walk_adds` / `walk_single_*` / `fsplit_fnode` are amp-parametric), so the only change is dropping the `bindsb` guards `denotes` strips through `ndenote_nonbinder`. The `.amp` leaf, vacuous at the floor, here wears the earlier stage -- the leaf that will defer to the supplied earlier-stage rank.
     - 4b-ii. The parallel within-stage recursion `w*Rank` / `w*Bound` over `walk n amp False` membership, parameterized by a supplied `(ampRank, ampBound)`, consuming 4b-i; and its faithfulness (the composition proof of step 2 with `amp` threaded through and the `.amp` leaf ranked by the supplied `ampRank`), given a faithful amp-rank -- the `hbound` / `hinj` input to 4a. Itself sliced:
       - 4b-ii-a. [landed] The recursion DEFINITIONS: the carrier `{s // walk n amp False s}`, the six mutually-recursive `wmRank` / `wnRank` / `wfRank` / `wmBound` / `wnBound` / `wfBound` over the `(amp, ampRank, ampBound)` triple, the carrier coercions (`walk_*_denotes` -- an amp-independent leaf/closure entry is a `denotes` entry), the generic two-predicate least split `someSplitP` (off the `denotes`-specific `IsHT`), and the one-step unfolding lemmas. The recursion parallels step 2 with three changes: the `.amp` leaf ranks by `ampRank` (bound `ampBound`), an amp-consuming factor (`.amp rest`, or a `.node n rest` head meeting `amp`) recurses instead of falling back, and the union spine drops the `bindsb` closure fallback (a bare `&` member consults `amp`); a nested closure (fold-of-binder, binder head) stays on the `typein (entryLt _)` fallback because its membership is amp-independent.
       - 4b-ii-b. [landed] The faithfulness proof `wmFaithful` / `wnFaithful` / `wfFaithful` (injectivity + the bound invariant) over the subtraction-free skeleton, given `Faithful ampRank ampBound` -- the composition proof of step 2 with `amp` threaded through, the `.amp` leaf discharged by the supplied faithful amp-rank, and the new amp-factor / binder-head product cases carried by the mixed-radix arithmetic (`mixmul_lt` / `mixmul_inj`) over the generic two-predicate split `someSplitP` (spec `someSplitP_spec`). Supporting: the value-preserving coercion extensionality `wentry_ext` (a `walk`-carrier entry equals a `denotes`/amp entry once their spellings agree) and the reduced product unfoldings `wfRank_amp_pos` / `wfRank_node_binder_pos` / `wfRank_node_nonbinder_pos`. `wnFaithful` is the per-stage `hbound` / `hinj` input to 4a's `stageRank_isWellOrder`; slice 4c feeds it with the real body at each stage.
   - 4c. [landed] Tie the knot: the closure rank by recursion on the stage index. `csData n : Nat -> Ordinal x (Spelling -> Ordinal)` is one pair-valued structural recursion pairing the per-stage bound with the per-stage rank; stage `k+1` carries an old entry (`stage n k`) at its stage-`k` rank and ranks a fresh body-spelling (`walk n (stage n k) False`) by 4b's `wnRank`/`wnBound` shifted past the earlier stages' width `csBound n k`, with the earlier stage's rank/bound supplied verbatim as the `(ampRank, ampBound)` -- so the "earlier-stage rank is strictly smaller" is literal (the stage-`k` data) and the recursion is manifestly well-founded (structural on `Nat`), no `decreasing_by`. Projections `csBound` / `csRank`, one-step unfolding equations (`csBound_zero` / `_succ`, `csRank_zero` / `_succ_old` / `_succ_new` / `_succ_none`), and the entry-level `cRank n e := csRank n (firstStage n e.1) e.1`. Purely definitional; stabilization across stages, injectivity, and the sup-over-stages total bound are 4d.
   - 4d. [landed] Closure faithfulness + swap: assemble injectivity via 4a fed by 4b/4c and the compositional bound (the sup over stages, the closure's order type), then replace the `typein (entryLt node)` fallback branches in `mRank` / `nRank` / `fRank` for binder nodes, fold-of-binder, and amp-products, extending `entryRecLt_isWellOrder` past the non-binder skeleton. Itself sliced:
     - 4d-i. [landed] Per-stage closure faithfulness `csFaithful n hsub k : Faithful (csRank n k on {s // stage n k s}) (csBound n k)`, by induction on the stage index `k` (given `nSubfree n`). Stage `0` is empty; stage `k+1` splits into the old block (carried at the stage-`k` rank, faithful by the IH, landing `< csBound n k`) and the fresh block (`walk n (stage n k) False`, ranked by 4b's `wnRank` off the IH as the amp-rank, landing in `[csBound n k, csBound n (k+1))` by `wnFaithful` fed the IH) -- disjoint ordinal intervals, so injectivity composes. This is the union-block disjoint-interval argument run along the stage ladder; the `hbound` / `hinj` per-stage input 4d-ii lifts to the entry level. Purely additive, no swap.
     - 4d-ii. [landed] Entry-level total-bound closure faithfulness: `cBound n` (the sup over stages of `csBound n k`, with `csBound_le_cBound` and the monotone ladder `csBound_mono`), cross-stage stabilization (`csRank_stable` -- once a spelling has appeared, every later stage carries it at the same rank, `csRank_succ_old` iterated -- specialized to first appearance as `csRank_firstStage`), the fresh-block lower bound `csBound_le_csRank_fresh`, stage-major disjointness at the entry level (`cRank_lt_of_firstStage_lt`: a strictly earlier first appearance is a strictly smaller `cRank` -- the earlier entry lands below its stage's bound by 4d-i, the later entry's stage opens at or past it), and `cFaithful : Faithful (cRank n) (cBound n)` for a genuine binder node (`bindsb n = true`, over `nSubfree`): different first stages separate by disjointness, a shared first stage reduces to 4d-i's `csFaithful`. Plus the fold-of-binder reinterpretation: `denotes_fold_binder` (the fold node itself binds nothing, so a fold-of-binder entry is exactly an inner-closure entry), the carrier map `foldBinderReinterp` / `foldBinderReinterp_injective`, and the routed-rank faithfulness `foldBinderFaithful` -- the branch 4d-iii installs on `mRank (.fold inner)` for a binder `inner`. Purely additive, no swap.
     - 4d-iii. [landed] The swap: the step-2 assembly (the mutual `mRank` / `nRank` / `fRank` / `mBound` / `nBound` / `fBound`, `entryRank` / `entryRecLt` and the free instances, the unfolding lemmas, the faithfulness mutual, the payoff, and leaf agreement) relocated below the closure machinery it now consumes, and the six closure fallback branches (`mRank` on `.amp`, fold-of-binder, and amp-product; `nRank` on a binder spine; `fRank` on `.amp rest` and a binder-tail `.node`) replaced by `cRank` with bounds `cBound` -- the fold-of-binder branch a dite on `bindsb inner` routed through `foldBinderReinterp` to the inner closure's `cRank` / `cBound`. `mFaithful` / `nFaithful` / `fFaithful` re-proved with the closure cases discharged by `cFaithful` / `foldBinderFaithful` instead of `faithful_typein`; `entryRecLt_isWellOrder`, the payoff, and the leaf-agreement statements unchanged in form, now over the genuinely body-recursive closure rank. `closureBound` survives solely as the 4b within-stage recursion's nested-closure fallback bound.
5. Migrate `entriesType` -> `prodLt` -> `unionLt` -> `Rows` onto `entryRecLt`, each a green build, deleting each approximation once its replacement is proved.
