# TODO: deferred increments

<!-- cspell:words uncomputable hejmark valueline slugify -->

Priority and rationale for outstanding work. This file only ranks what remains and says why; two ledgers stay authoritative -- the **"What this does not prove"** section of `static/lean/README.md` for the mechanization, and `docs/foundation/ROADMAP.md` for the layers. When an item lands, update its ledger first.

## Do next

Ordered by dependency, not by size.

- [ ] **Carry the rewrites into the Rust port** -- the port is now *slower* than Python on every measured row, and the four rewrites that did it are all portable. Engine performance, below.
- [ ] **Bound the last split search** -- `capture._splits` is the one that did not get the cut bound, because its factors are a different type. Small and self-contained.
- [ ] **Re-time the `programs/` tier** -- its stated blocker was matcher cost, and that blocker is gone. Deferred, below.

The previous four are done; **Landed** records what they cost and, where the guess was wrong, what was actually true.

## Landed

### Refuse past a work budget

`hejmark/core/floor/work.py`. `budgeted` opens a budget over a run and `charge` spends it; `HimarkBudgetError` is the diagnostic, exported beside the other four. `match` and `finditer` open one per match, `emit._iterate` one per contracting pass, and the outermost open budget is the one that holds, so a pass is priced whole rather than per match inside it.

**The unit was the surprise, and it decided where the module lives.** The obvious charge is one matcher probe, and that measures nothing: at 120 characters the closure scan below spent **four** probes and eleven seconds, because the cost is *inside* a single `contains`. So the unit is one membership question -- one `Universe.contains` call, memo hits included, since re-asking an answered question still costs the asking -- and the module therefore sits on the floor, the only layer that can see the work. Denotation stays total; a budget decides only whether this host keeps computing, which is exactly L2's remit.

`HimarkBudgetError` is its own class rather than the reads' `HimarkScopeError`, because L2 separates them too: a read that outruns its budget cannot name an entry, where a run past the work budget could name every one and simply could not afford to.

### Bound the product probe

`hejmark/core/floor/reach.py`, the companion to `ceiling.py`: `reach` measures spellings where `cardinality` counts entries, both structural, both `None` for "no known bound, never a wrong one". `cuts` reads a split range off the expression and is used by all three split searches that took it -- `match._probe`, `universe._splits`, `measure._tilings`.

**Both ends of the cut turned out to matter, and the second end was the whole win.** The factor's own reach caps the cut, which is what `L2.md` named; the reach of the factors *after* it floors the cut, because a cut leaving them more text than they can spell together completes nowhere. That corollary collapses the language's idiomatic closure: in `{@x, &@x}` the `&` reaches nowhere, but the single-character factor beside it pins the cut to one position, turning a scan of every cut into a look at one. `L2.md`'s first permitted rewrite now states both ends.

### Chart memo across start positions

`match._Search.chart`, keyed on `(factor index, start position)` and shared across start positions and across the matches of one `finditer`. `_plain` marks the first depth whose tail carries no `Late`, and only from there down does the chart apply -- a back-referencing factor denotes only under its bindings, so the same depth at the same position is not the same question twice.

**It does nothing for the queries that looked slow, and everything for a shape nobody had measured.** On two- and three-factor closure queries it is inside the noise, because the membership memo one level down already collapses those subproblems. On a product of many factors it moves the degree exactly as advertised: `{@r}` six times over 32 characters went from **70.2 s to 0.09 s**, and the chart column is flat in the factor count where the plain column grows like $n^{k}$.

### Price the contraction measure

Profiled, and the guess in this file was wrong twice over.

`precedes` is **not** the cost. It does not appear in the profile at all -- milliseconds against seconds -- exactly as its documented never-streams property predicts. What a contracting pass actually spends is the **seat**: `measure.contains(document)`, ordinary closure membership over the whole document, run before and after each pass. So contraction was never a construct with its own cost; it was closure membership, priced once per pass, and it fell with everything else.

The profile did surface one thing nothing else would have: `builtins.hash` at **6.4 s of 9.1 s self time**, 11.6 million calls. A generated dataclass hash walks the whole subtree, and every memo lookup hashes an AST node. `UniverseNode.__hash__` now remembers its own hash, which cut hash calls 21-fold. Two details are load-bearing and were measured rather than assumed:

- Doing the same to `Universe` makes things **worse**. A `Universe` is built fresh on nearly every call, so a remembered hash there is never read twice and costs more than it saves. Long-lived nodes remember; ephemeral ones do not.
- An earlier note rejected this fix as marginal. It was, then. Re-measuring after the cut bounds changed the answer -- which is the argument for profiling each time rather than carrying a verdict forward.

### Keep the descent shallow

Not planned; found by the fix above. Narrowing the cut range moves the *longest* sub-question to the front of the search, and the closure recursion descends one character per level, so the stack blew before the budget did -- a `RecursionError` at 100 characters where the old code reached 160. `universe._shorter_first` answers the shorter prefixes first, so the descent finds its answers in the memo instead of a frame deeper. Only the closure at omega warms; warming its stages too costs four times as much and buys nothing, since answering the omega question at each prefix has already filled their member walks.

This is a tactic, not a rule -- a host whose stack is its memory conforms without it -- and it is worth knowing that it also made the engine *faster*, not just deeper.

## Engine performance

Measured, not guessed. Cold, one workload per process, against `2ab4c14`:

| workload | before | after | factor |
| --- | --- | --- | --- |
| `{\*}{@r}{\*}` @30 | 0.214 s | 0.030 s | 7x |
| `{\*}{@r}{\*}` @60 | 4.04 s | 0.272 s | 15x |
| `{\*}{@r}{\*}` @100 | 38.7 s | 1.11 s | 35x |
| `{\*}{@r}{\*}` @160 | 225.8 s | 5.66 s | 40x |
| `{@r}`×4 `{\*}` @32 | 5.59 s | 0.077 s | 73x |
| `{@r}`×6 `{\*}` @32 | 70.2 s | 0.090 s | 780x |
| bare collapse, 40 dashes | 6.10 s | 0.065 s | 94x |
| bare collapse, 60 dashes | 17.4 s | 0.152 s | 114x |
| slugify @37, no collapse | 0.673 s | 0.090 s | 7x |
| slugify @37, with collapse | 4.76 s | 0.140 s | 34x |

Read the two halves differently. For a fixed query shape the growth is still **~O(n³·⁵)**, down from ~O(n⁴): the cut bounds and the remembered hash moved the *constant*, by roughly forty. For a product of many factors the chart moved the *degree*, from $n^{k}$ to about $n^2$, which is the 780x row. Both were needed and neither substitutes for the other. Full timings and method are in `docs/.TEMP.md` (local-only; gitignored under "Private project files").

### 1. Carry the rewrites into the Rust port

`tests/benchmarks/` now reports Python **winning every 800-character row**, by up to 5x, and widening with target length -- the exact reversal of what `CLAUDE.md` recorded a week ago, including the direction of the trend. (The 200-character rows still favour Rust, but at that size Python's parse and warm-up dominate its own number, so they say little.) Nothing regressed in Rust; Python simply took four rewrites the port does not have: the two-ended cut bound (`reach.rs`), the chart, the remembered node hash, and the membership memo the port already documents omitting.

The order to port them in is the order they paid here: the cut bound first (it is the largest and it is pure structure over the AST the port already decodes), then the memo, then the hash, then the chart. The benchmark asserts spans rather than timings, so none of this fails a gate -- which is why it needs writing down instead.

### 2. Bound the last split search

`capture._splits` still walks every cut. It missed the sweep for a type reason and not a semantic one: its factors are `Factor` (`Universe | Late`), where `cuts` takes the floor's `UniverseNode | Closure`, and a `Late` has no reach until its reads are bound. Resolving each factor first and reaching the result would fix it. This is the `$1..$n` read path, already budgeted and off the hot loop, so it is small -- but it is the one place the permitted rewrite is stated and not taken.

### 3. The descent is still linear in the spelling

`_shorter_first` bounds the stack for the shape that matters -- a closure whose sub-questions are prefixes, which is every `{@x, &@x}` in the std -- but the bound is structural, not general: a closure whose split search asks about suffixes or interior substrings will descend one frame per character again and can still exhaust the interpreter's stack before the work budget fires. A `RecursionError` is not a diagnostic, so this is the one path where "never a hang, never a guess" is met by neither. Worth stating in `L2.md`'s diagnostics only if a real shape hits it; worth fixing properly (a bottom-up table over stage and substring) only if one does.

## Deferred

### Examples: a `programs/` tier

A third example group beside `simple/` and `demos/` -- whole programs rather than feature demos. Planning, the porting-gap analysis against the older iteration's `scripts/`, and four verified-working program sources are parked in `docs/.TEMP.md`.

**The stated blocker is gone.** It was matcher cost: the flagship candidate (markdown to HTML) took 6.26 s on a three-line fixture and hung at six, and slugify was too slow to ship with its collapse statement. Slugify now runs in 0.140 s at 37 characters *with* the collapse, a 34x change, so the tier's cheap candidates can ship today and the flagship needs re-timing rather than re-architecting. That re-timing is the work: if markdown-to-HTML now runs a six-line fixture inside the gate's patience, the tier ships as planned.

### Language surface: expressive render layer

**The gap.** A cast by value is uncomputable today. `@lo..hi` cuts one head's value line and names its bounds in that head's own numerals, so writing a bound value under a *second* universe -- decimal to hex, a unary run's length as a decimal numeral -- is value-indexing across two radixes, which no expression computes and no register spells (`docs/foundation/L1_5.md`, Worked derivations).

**The groundwork, landed.** A render that carries a computed value needs somewhere for that value to land, and the natural bound is the target universe's own entry count -- its **ceiling** -- so a value that overflows folds back modulo the ceiling and always names an entry that exists. `hejmark/core/floor/ceiling.py` prices it: `cardinality` computes the count structurally, never streaming an entry, so an astronomically wide field costs nothing to price. It is exact over disjoint faces and ranges and products of those, and returns `None` -- "no known ceiling", never a wrong one -- wherever the collision rule might drop an entry (an overlap, a subtraction) or a member is unbounded (a final segment, a closure). Nothing consumes it yet, by intent. `reach.py` is now its companion and the precedent is no longer theoretical: a structural price, `None` where it cannot be exact, consumed by the layer above.

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
