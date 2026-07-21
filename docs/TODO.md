# TODO: deferred increments

<!-- cspell:words uncomputable hejmark -->

Priority and rationale for outstanding work. This file only ranks what remains and says why; two ledgers stay authoritative -- the **"What this does not prove"** section of `static/lean/README.md` for the mechanization, and `docs/foundation/ROADMAP.md` for the layers. When an item lands, update its ledger first.

## Do next

Ordered by dependency, not by size. The first two are cheap and unblock judgement about the rest.

1. **Green the gate** -- a permanently red `uv run pytest` cannot tell a regression from the usual noise. Housekeeping, below.
2. **Settle what L2 covers** -- decides whether the next three items are chasing a stated bound or an unstated preference. Layers, below.
3. **Bound the product probe** -- the largest single measured win still on the table. Engine performance, below.
4. **Chart memo across start positions** -- the change that moves the polynomial degree rather than its constant.
5. **Price the contraction measure** -- `<=>` is now the most expensive construct in the language, and it is unprofiled.

Everything under **Deferred** waits on something that does not yet exist: a row, a use that forces a design, or one of the five above.

## Housekeeping

### Green the gate

`uv run pytest` is the gate, and it has been failing 2 of 407 for reasons unrelated to any current work: `test_ruff_check` and `test_ruff_format`, both only on `gui/`. Every run now needs a human to confirm the two failures are still *the same* two -- which is exactly how a real regression gets waved through.

Three parts, none of them deep:

- `gui/hejmark/` is an **untracked vendored copy** of the package (a build/bundle byproduct) that is *not* gitignored, so ruff lints it. It carries both the `INP001` finding and one of the four format failures. Adding it to `.gitignore` should drop both, since ruff respects gitignore by default.
- Three committed files need `ruff format`: `gui/tests/benchmarks/conftest.py`, `gui/tests/benchmarks/test_engine_speed.py`, `gui/tool/make_icons.py`.
- Re-run and confirm 407 pass. If `gui/` is meant to be outside the gate entirely, the honest fix is instead to scope the lint tests' paths and say so in `CLAUDE.md`.

## Layers

### Settle what L2 covers

`L2.md`'s scoping paragraph draws its line at **admission**: a rule that changes which programs are admitted is normative, an optimization that changes only speed "lives nowhere in the foundation" (*Guards, not tricks*). That is narrower than the layer's stated intent, which was to house anything affecting performance or guarding against performance failure.

The proposal on the table is to redraw the line at **observable versus constant-factor**, giving three tiers instead of two:

- **Cost bounds** -- normative, and absent today. "A guarded query against text of length *n* completes in time polynomial in *n*, or is refused." Complexity class is observable: it decides whether a program completes at all. Without a stated bound, the finish line's "never a hang" is unfalsifiable, which is precisely the situation below.
- **Semantics-preserving rewrites** -- normative as *permissions*. Each is a theorem (`rewrite(e) ≡ e`) whose correctness is a language-level claim, and `L1.md`'s "Compression, not capability" is already exactly such a catalog, so the precedent exists.
- **Tactics** -- out. Memo sizing, the closure seal, window carving: constants, not classes.

Guardrail if adopted: state permissions and bounds, never mandated mechanisms, so the layer does not churn with every performance patch and a host that reaches the same bound differently stays conforming.

### L2 conformance: the hang

`L2.md` promises "every read the surface admits either completes within a stated bound or is refused with a diagnostic -- never a hang, never a guess." A closure query over a long enough document hangs: not refused, not bounded.

Worth noting that the performance items below **raise the ceiling but never remove this**. There is always a document long enough, so a bound with a diagnostic is needed regardless of how fast the matcher gets -- the shape already exists in `capture.BUDGET` for `$0`. Faster matching and an honest refusal are complementary, not alternatives.

## Engine performance

Measured, not guessed. Growth is **~O(n³·³)** -- polynomial, not exponential. Memoizing `_spells` in `core/floor/universe.py` (landed) cut the constant by ~10x and the whole suite from 120s to 91s, but did not move the degree. Full timings and method are in `docs/.TEMP.md` (local-only; it is gitignored under "Private project files").

Diagnosis that produced the landed fix, worth keeping: `_contains.cache_info()` showed **1,038,323 hits against 1,250 misses** at 31 characters. The memo was never thrashing -- the recursion simply re-asked memoized questions a million times. Look at call *counts* before cache sizes.

### 1. Bound the product probe

`_try_product` in `core/scan/match.py` probes **every** length at every product position (`for length in range(len(text) - pos, 0, -1)`), including for a factor that can only ever wear a one-character face. A single-face factor therefore costs O(n) `contains` calls where one would do.

The fix is a max-face-length analysis: structural, never streaming, `None` when unbounded -- the same shape and spirit as `core/floor/ceiling.py`, which is already the precedent for "price it from the AST or admit you cannot". Self-contained, and the largest single win still available.

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
