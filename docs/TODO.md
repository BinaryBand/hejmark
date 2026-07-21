# TODO: deferred increments

<!-- cspell:words uncomputable hejmark valueline slugify catchable -->

Priority and rationale for outstanding work. This file only ranks what remains and says why; two ledgers stay authoritative -- the **"What this does not prove"** section of `static/lean/README.md` for the mechanization, and `docs/foundation/ROADMAP.md` for the layers. When an item lands, update its ledger first.

## Do next

Ordered by dependency, not by size.

- [ ] **Teach the Rust port the Program wire format** -- `core/ir/wire.py` serializes whole compiled scripts (statements, templates, measures, sentinel table, late slots), versioned from day one; Rust currently reads only the bare-query shape from `core/ir/codec.py`. A Rust reader for the Program format gets it `run` (slot-free scripts) rather than just `find`. Slotted programs additionally need a resolver channel back into the compiler -- design that only when a consumer exists.

The previous eight are done; **Landed** records what they cost and, where the guess was wrong, what was actually true.

## Landed

### Carry the rewrites into the Rust port

All four, plus a fifth nobody had named. The port wins every benchmark row again, and the 800-character rows -- the ones it was losing by up to 5x -- now sit at the floor, where process spawn and JSON decode are most of the number:

| workload | before | after | factor |
| --- | --- | --- | --- |
| `{a, &{b}}` @9 | 87.4 ms | 0.7 ms | 125x |
| `{{cat,feline}}` @800 | 18.7 ms | 0.8 ms | 23x |
| `{a..c, !{b}, b}` @800 | 12.8 ms | 1.0 ms | 13x |
| `{0..9}` @800 | 9.7 ms | 0.8 ms | 12x |
| `{a..e}` @800 | 10.3 ms | 1.0 ms | 10x |
| `{a}{b}` @800 | 3.9 ms | 0.8 ms | 5x |
| `{a}` @800 | 3.8 ms | 0.9 ms | 4x |

**The stated order was wrong, and following it would have crashed the port.** This file said cut bound first, then the memo. That was the order they paid in *Python*, where the memo already existed. Here the cut bound is what makes the descent deep -- it moves the longest sub-question to the front -- and `_shorter_first` answers that only by warming a memo. Cut bound first would have meant a deep unwarmed descent, and a Rust stack overflow is a hard abort, not a catchable error. The order that works is **memo, then cut bound with the warming attached, then the chart**.

**The fifth rewrite was a deep clone nobody had counted.** `Universe::sealed` rebuilt its whole subtree on every call, and it is called from inside the split search's inner loop -- once per candidate cut. Holding nested nodes behind `Rc` makes it a refcount bump. That alone is most of the `{{cat,feline}}` row, and it is also what gives a node a stable address, so it is the same edit as the memo key.

**The remembered node hash did not need porting at all.** Python remembers a structural hash because it has no node identity to key on; a shared node has an address, so the memo keys on `(node, amp-key, stage)` by pointer and never hashes a subtree. Identity implies equality, so this is sound and strictly cheaper -- the trade is that two structurally equal but separately built nodes miss each other, which is a recomputation and never a wrong answer. The one thing it demands is that the key *hold* the `Rc`: an address identifies a node only while the node is alive, and a freed one's address goes straight to the next allocation.

**A memo that always wins in Python does not always win here.** Memoizing unconditionally made the 800-character rows **78x slower** -- Python's per-call overhead hides a hash lookup, Rust's does not, and the base operation is a slice comparison. The memo is now gated on `amp.is_some() || binds(node)`: a question recurs under a closure and nowhere else. Gated, the closure row is 125x faster and the rest is untouched.

**And capping the memo is worse than not capping it** -- see the new *Do next* item. Clearing wholesale at 65536 answers took `{a, &{a}}` over 400 characters from 8.5 s to past 90 s; filling-and-holding did the same, because past the cap the recursion is un-memoized either way. Unbounded, the curve is smooth (0.7 s at 200 characters, 8.5 s at 400, 70 s at 700) and memory tracks the work rather than the input (14 MB, 92 MB, 470 MB). The right bound is a work budget on the run, not a cap on the memo.

### Refuse past a work budget

`hejmark/core/floor/work.py`. `budgeted` opens a budget over a run and `charge` spends it; `HimarkBudgetError` is the diagnostic, exported beside the other four. `match` and `finditer` open one per match, `execute._iterate` one per contracting pass, and the outermost open budget is the one that holds, so a pass is priced whole rather than per match inside it.

**The unit was the surprise, and it decided where the module lives.** The obvious charge is one matcher probe, and that measures nothing: at 120 characters the closure scan below spent **four** probes and eleven seconds, because the cost is *inside* a single `contains`. So the unit is one membership question -- one `Universe.contains` call, memo hits included, since re-asking an answered question still costs the asking -- and the module therefore sits on the floor, the only layer that can see the work. Denotation stays total; a budget decides only whether this host keeps computing, which is exactly L2's remit.

`HimarkBudgetError` is its own class rather than the reads' `HimarkScopeError`, because L2 separates them too: a read that outruns its budget cannot name an entry, where a run past the work budget could name every one and simply could not afford to.

### Bound the product probe

`hejmark/core/floor/reach.py`, the companion to `ceiling.py`: `reach` measures spellings where `cardinality` counts entries, both structural, both `None` for "no known bound, never a wrong one". `cuts` reads a split range off the expression and is used by all three split searches that took it -- `match._probe`, `universe._splits`, `measure._tilings`.

**Both ends of the cut turned out to matter, and the second end was the whole win.** The factor's own reach caps the cut, which is what `L2.md` named; the reach of the factors *after* it floors the cut, because a cut leaving them more text than they can spell together completes nowhere. That corollary collapses the language's idiomatic closure: in `{@x, &@x}` the `&` reaches nowhere, but the single-character factor beside it pins the cut to one position, turning a scan of every cut into a look at one. `L2.md`'s first permitted rewrite now states both ends.

### Chart memo across start positions

`match._Search.chart`, keyed on `(factor index, start position)` and shared across start positions and across the matches of one `finditer`. `_plain` marks the first depth whose tail carries no `Slot`, and only from there down does the chart apply -- a back-referencing factor denotes only under its bindings, so the same depth at the same position is not the same question twice.

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

### Give the Rust port a work budget

`rust/src/floor/work.rs`, a port of `core/floor/work.py`. `budgeted` opens a per-run budget and `charge` spends it, thread-local and one deep -- a nested call while one is already open rides it rather than opening a second, the same outermost-holds rule the Python's list-based `_OPEN` enforces. `Universe::contains` charges once per call at the top, memo hits included, exactly the chokepoint the Python charges; `measure::owner_of` charges by hand for the three walks that go around `contains`, mirroring `_owner` on the Python side. `match_` and `finditer` each open one budget per match. A contracting pass has no Rust runner yet (there is no `execute.rs`), so that half of the Python's two call sites has nothing to wire today; the module's doc comment says so rather than leaving it looking like an oversight.

**The Rust language forced one honest divergence.** Python raises `HimarkBudgetError` as a catchable exception; Rust has no equivalent control-flow type, so it unwinds via `panic_any` exactly as `HimarkUnsettledError` already does two doors down in `universe.rs` -- a caller recovers it with `catch_unwind` and `downcast_ref::<HimarkBudgetError>()`. Nothing downstream catches it yet (`find.rs` doesn't catch `HimarkUnsettledError` either), so today a budget refusal surfaces as a Rust panic rather than a clean CLI message -- an existing gap this item did not create and did not close.

**The memo is capped now, and only now is that safe.** `Universe`'s membership memo (`CONTAINS`) evicts its oldest `(universe, spelling)` answer past 65536 entries, mirroring the Python's `lru_cache(maxsize=65536)` -- FIFO rather than true LRU, since which answer survives no longer changes correctness or the exponential-blowup risk, only how much of an affordable run's memo is reused. It is safe for the same reason capping it was unsafe before: a run that would outgrow the cap now hits the work budget first and is refused, so the eviction cliff measured in *Carry the rewrites into the Rust port* above never has anywhere to bite. Verified directly: `{a, &{a}}` over 2000 characters, unbounded before this landed, now unwinds cleanly with a `HimarkBudgetError` naming the budget instead of growing memory without end.

### Ship the `programs/` tier

Five files under `static/examples/programs/`: `html-escape`, `normalize-space`, `slugify`, `wrap` -- unchanged from the candidates parked in `docs/.TEMP.md` -- and `markdown-to-html`, rewritten rather than re-timed as-is.

**The flagship needed rewriting, not just re-timing.** The old iteration's `scripts/md_html.hmk` is written against a materially different surface -- `[1..]`-style quantifiers, filter blocks, template pipes, none of which this grammar has (repetition is closure `&` in a named `uni`; see `docs/.TEMP.md`'s porting-gap table, now folded into this entry since that file is deleted). No verified source for the flagship survived alongside the timings, only the fixture: input `# Title`, `some *b* and` a backtick-quoted `c`, `## Sub` (three lines) rendering to `<h1>Title</h1>`, `some <b>b</b> and <code>c</code>`, `<h2>Sub</h2>`. `markdown-to-html.hmk` is a from-scratch subset written to that fixture -- ATX `#`/`##` headings, one level of `*em*`, one level of backtick-quoted code -- using the same per-line sentinel-masking idiom `demos/bubble-sort.hmk` uses for its own line anchor, since the grammar has no `{@<}`/`{@>}`. Lists, tables, links, blockquotes and fenced code are out of scope; re-architecting them (the old `format_html.hmk`'s indentation-via-template-pipe step, especially) is a separate, larger effort this item did not attempt.

**The blocker really is gone.** The fixture above now runs in ~0.09 s, against the old 6.26 s that used to make three lines the practical ceiling. A six-line, 75-character stress fixture (three headings, two inline spans, one deliberately-out-of-scope `###` line) finishes in ~1.3 s and produces the expected output rather than hanging -- slower than the shipped fixture because it does more work, not because anything is exponential again. The four non-flagship candidates are all under 30 ms.

`tests/integration/test_examples.py`'s `SCRIPTS` table grew five entries; the glob-versus-table check means the tier could not ship partially covered.

### Bound the last split search (Python only)

`hejmark/core/compiler/late.py`'s `unit_reach`, riding `LateSlot.reach` (`core/ir/program.py`) into `Slot.reach` (`core/engine/scan/match.py`) and read by `capture.py`'s new `_factor_reach`/`_suffixes`/`_cuts` -- a small mirror of `reach.factor_reach`/`suffixes`/`cuts` retyped for `Factor` (`Universe | Slot`) rather than the floor's `UniverseNode | Closure`, which was the type reason this search missed the sweep the other three took. `compile_query` computes each factor's reach as it builds the query left to right -- an eager factor's from `reach.reach`, a slotted one's from `unit_reach` -- so a slot's own bound can read the reach already known for the factors its reads name, without ever denoting anything.

**The bound is sound by construction, not by case-covering every surface shape.** `unit_reach` prices only what it can price exactly: a bare read (`{$1}`) or one alongside literal faces and nested groups, summing like a product, with a read contributing at most the referenced factor's own reach -- because `late._sub_segment` turns it into exactly that long a `Face` and nothing longer. Everywhere the pipeline, an exponent, a value cut, or a name could stretch the shape in a way not worth chasing, it returns `None` ("no known bound") exactly as `floor.reach` already does for the eager case -- a slot with no known bound simply falls back to the unbounded search that ran before this existed. Nothing here risks a bound a real substitution could exceed; the worst outcome of being conservative is an unimproved split search, never a missed match.

**Rust needed nothing.** `capture.rs` has no `Slot` at all -- the port's factors are plain universes -- so `docs/TODO.md`'s "Rust half is done" note from before this landed still stands; this item was Python-only start to finish.

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

### 1. The descent is still linear in the spelling

`_shorter_first` bounds the stack for the shape that matters -- a closure whose sub-questions are prefixes, which is every `{@x, &@x}` in the std -- but the bound is structural, not general: a closure whose split search asks about suffixes or interior substrings will descend one frame per character again and can still exhaust the interpreter's stack before the work budget fires. A `RecursionError` is not a diagnostic, so this is the one path where "never a hang, never a guess" is met by neither. Worth stating in `L2.md`'s diagnostics only if a real shape hits it; worth fixing properly (a bottom-up table over stage and substring) only if one does.

## Deferred

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
