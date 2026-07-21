# TODO: deferred increments

<!-- cspell:words uncomputable hejmark valueline -->

Priority and rationale for outstanding work. This file only ranks what remains and says why; two ledgers stay authoritative -- the **"What this does not prove"** section of `static/lean/README.md` for the mechanization, and `docs/foundation/ROADMAP.md` for the layers. When an item lands, update its ledger first.

## Do next

Ordered by dependency, not by size.

- [ ] **Refuse past a work budget** -- the one place the implementation now contradicts a normative claim. Conformance, below.
- [ ] **Bound the product probe** -- the largest single measured win, and now a rewrite `L2.md` names. Engine performance, below.
- [ ] **Chart memo across start positions** -- the change that moves the polynomial degree rather than its constant.
- [ ] **Price the contraction measure** -- `<=>` is now the most expensive construct in the language, and it is unprofiled.

Everything under **Deferred** waits on something that does not yet exist: a row, a use that forces a design, or one of the four above.

## Conformance

### Refuse past a work budget

`L2.md` now states a cost tier, and the implementation meets one half of it and not the other. The **class** holds: matching is polynomial in the text (see below), which is what the contract asks. The **budget** does not exist: a closure query over a long enough document runs until someone kills it, where the contract says a run past the host's work budget is a diagnostic.

The shape is already in the tree twice -- `capture.BUDGET` for `$0` and an ambiguous factor split, `valueline.RADIX_BUDGET` for a value cut -- and this is the third instance of the same rule, over a match and over a contracting pass. Note the performance items below **raise the ceiling but never remove this**: there is always a document long enough, so an honest refusal is needed regardless of how fast the matcher gets. The two are complementary.

Decided while settling the layer's scope, and worth recording because it sets the target: the line is drawn at **observable versus constant-factor**, three tiers rather than two. Admission rules and cost bounds are normative; a meaning-preserving rewrite is normative as a *permission*, since each is a theorem and `L1.md`'s compression catalog is already a list of exactly that kind; tactics -- memo sizing, the closure seal, window carving -- are out, as constants rather than classes. The guardrail is that the layer states bounds and permissions and never mandates a mechanism, so a host reaching the same bound differently stays conforming and the layer does not churn with each performance patch.

## Engine performance

Measured, not guessed. Growth is **~O(n³·³)** -- polynomial, not exponential. Memoizing `_spells` in `core/floor/universe.py` (landed) cut the constant by ~10x and the whole suite from 120s to 91s, but did not move the degree. Full timings and method are in `docs/.TEMP.md` (local-only; it is gitignored under "Private project files").

Diagnosis that produced the landed fix, worth keeping: `_contains.cache_info()` showed **1,038,323 hits against 1,250 misses** at 31 characters. The memo was never thrashing -- the recursion simply re-asked memoized questions a million times. Look at call *counts* before cache sizes.

### 1. Bound the product probe

`_try_product` in `core/scan/match.py` probes **every** length at every product position (`for length in range(len(text) - pos, 0, -1)`), including for a factor that can only ever wear a one-character face. A single-face factor therefore costs O(n) `contains` calls where one would do.

The fix is a max-face-length analysis: structural, never streaming, `None` when unbounded -- the same shape and spirit as `core/floor/ceiling.py`, which is already the precedent for "price it from the AST or admit you cannot". `L2.md` now names this rewrite under *Permitted rewrites*, so it is licensed rather than merely tempting. Self-contained, and the largest single win still available.

### 2. Chart memo across start positions

`match()` re-runs the whole product search at every start position and shares nothing between them. A memo keyed on `(factor index, span)` is the textbook fix and is what actually lowers the degree rather than the constant. Bigger change than item 1; do it after, so the two wins can be told apart.

### 3. Price the contraction measure

`<=>` is now the most expensive construct in the language: at 37 characters, slugify costs 0.31s without its collapse statement and 3.95s with it; a bare collapse over 60 dashes costs 13.45s. Each pass compares two documents under a closure-over-`@C` measure, so cost scales with document length *and* pass count.

This is measured but **unprofiled** -- `precedes` in `core/scan/measure.py` has not been looked at, and its documented property is that it never streams, so the cost is presumably in the membership calls underneath. Profile before designing anything.

## Deferred

### Examples: a `programs/` tier

A third example group beside `simple/` and `demos/` -- whole programs rather than feature demos. Planning, the porting-gap analysis against the older iteration's `scripts/`, and four verified-working program sources are parked in `docs/.TEMP.md`.

Blocked on the performance items: the flagship candidate (markdown to HTML) runs correctly but takes 6.26s on a three-line fixture and hangs at six lines, which is too slow for the gate. The closure-free candidates (`html-escape`, `normalize-space`, `wrap`) are fast today and could ship at any time if a smaller tier is wanted sooner.

### Language surface: expressive render layer

**The gap.** A cast by value is uncomputable today. `@lo..hi` cuts one head's value line and names its bounds in that head's own numerals, so writing a bound value under a *second* universe -- decimal to hex, a unary run's length as a decimal numeral -- is value-indexing across two radixes, which no expression computes and no register spells (`docs/foundation/L1_5.md`, Worked derivations).

**The groundwork, landed.** A render that carries a computed value needs somewhere for that value to land, and the natural bound is the target universe's own entry count -- its **ceiling** -- so a value that overflows folds back modulo the ceiling and always names an entry that exists. `hejmark/core/floor/ceiling.py` prices it: `cardinality` computes the count structurally, never streaming an entry, so an astronomically wide field costs nothing to price. It is exact over disjoint faces and ranges and products of those, and returns `None` -- "no known ceiling", never a wrong one -- wherever the collision rule might drop an entry (an overlap, a subtraction) or a member is unbounded (a final segment, a closure). Nothing consumes it yet, by intent.

**Why it is deferred.** It is a denotational addition, so it grows L1.5 rather than the execution contract -- and a new register faces the scrutiny a new axiom does, since L1.5's finish line is measured by the inventory staying four tokens. The design is not forced yet; the first script that genuinely wants it should settle:

- which token spells the render, and whether it is a register at all or a template form;
- what a `None` ceiling refuses -- an infinite target carries no modulus, so the render is a diagnostic there, which puts it on the finite-execution contract's shelf (`docs/foundation/L2.md`);
- whether the wrap is a modulo or a saturating cut, and whether what is rendered is the entry's own value or something computed from it.

The old iteration's `levenshtein`, `fuzzy_*`, `math` and `bench_report` scripts are the concrete demand for this: they are the ones that cannot be written at all, as opposed to merely rewritten.

### Lean mechanization

Deferred until needed -- each item waits on a row or a layer that does not yet exist. The last item with a hard case unmechanized on real syntax, **in-range-seam survivors**, landed as `inSeamRow_entryRecType` in `L1/Bridge/Rows.lean`: the seam row `{b}{a..}{b}{a..}` with the marker drawn from inside the closure range, where the splits genuinely collide (`inSeamRow_splits_collide`) yet the recursion's own least-split choice keeps the marker-free heads (`inSeamRow_someSplit`, `inSeamRow_survivor`) and $\omega^2$ survives -- phase F's abstract `seam_collision_survives`, now on a real term.

#### 1. N-ary `Factors` positional machinery

No n-ary analogue of `entryRecType_prod2` reading a whole factor list as one mixed-radix positional order (`fRank` is n-ary; the type law is binary-only). Pure generalization -- the abstract n-ary theory already exists in `L1/Order/Positional.lean` and every current row needs only the binary form. Do it the day a row needs three factors.

#### 2. Converse half of the admission test

Every closure-free universe has a regular face set. Needs a DFA / symbolic automaton construction for shortlex windows over the infinite code space -- the heaviest lift, for the least payoff: the direction that guards the spec (closure's witness `{ab, {a}&{b}}` is not regular, so closure cannot be compressed away) is already proved in `L1/Membership/Admission.lean`. No code path relies on the converse.

#### 3. Face axis on real syntax

The ordinal-level face-vs-entry distinction (`{{{},0}}{0..9}` and kin) is not mechanized over real syntax; the north-star parse gate only accepts the rows. Guards doc claims only: the Python core is membership-only (`Match` carries spans and faces, no values), so there is no executable behavior for this to catch. Becomes interesting only if a future layer computes with face indices.
