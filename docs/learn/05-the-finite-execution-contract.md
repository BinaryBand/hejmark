# Lesson 5: The finite-execution contract

L1 is total: every expression denotes, no matter how weird. L1.5 adds no new denotation, only surface. Neither layer ever refuses a program that compiles. And yet an unguarded closure over `{a, &}` genuinely can spend forever deciding whether some spelling is absent (lesson 3's fixpoint theorem told you exactly why: absence in an unguarded body carries no bound). Something has to turn "this all denotes, mathematically" into "and this finishes running on your laptop." That something is **L2**, `docs/foundation/L2.md` -- the finite-execution contract. It is the newest of the four layers and the only one whose whole job is *operational*: not what a script means, but what it costs to answer, and what happens when the cost has no bound.

L2 does exactly two things, and they are opposites in spirit: it makes some computations *cheaper without changing their answer* (rewrites), and it makes some computations *refuse outright* rather than run forever or guess (refusals).

## Permitted rewrites: same answer, less work

A rewrite is licensed only if it changes *how* an expression is computed and never *what* it denotes. Two families exist.

### Reach: pricing a split search before you run it

A product's membership search has to try splitting the text at every plausible boundary between factors. **Reach** is an upper bound, read directly off the *expression itself* (never by actually running anything), on how long a face any given factor could possibly wear -- and that bound lets the search skip trying splits it can already tell will fail.

- A single code point or a bounded range reaches exactly `1`.
- A literal reaches its own length.
- A product reaches the sum of its factors' reaches.
- A closure (`&`) reaches unbounded -- there is no shortcut there, and none is claimed.

| Query | On | Cut | Why |
| --- | --- | --- | --- |
| `{a..z}{0..9}` | `a5` | `a` \| `5` | each factor reaches 1 -- there is only one place to cut |
| `{cat}{0..9}` | `cat5` | `cat` \| `5` | `{cat}` reaches 3, pinning exactly where the second factor must start |
| `{{a..z,&{a..z}}}{\!}` | `hello!` | `hello` \| `!` | the trailing `{\!}` reaches 1, so only the very last character needs probing against the unbounded closure -- one probe instead of trying every prefix length |

The bound is *only ever* an upper one -- reach never claims a factor is shorter than it might really be, because under-approximating there would silently drop a real match. Anything reach cannot price exactly is priced *unbounded*, which costs a probe rather than a correctness bug. Subtraction is not priced at all: stripping faces can only ever shrink a set, so it cannot make anything reach further than it otherwise would. Where the pieces genuinely have to cover the text exactly -- a product's own membership question, or the re-split a back-reference capture needs -- reach is read from *both* ends, because a cut that leaves the remaining factors more text than they could possibly spell between them can be discarded outright.

This rewrite lives close to the floor, deliberately: `core/floor/reach.py` computes it once, off the plain syntax tree, and both `denote/split.py` (deciding a product) and `scan/match.py` (the actual text scan) spend it.

### Value-cut collapse: when a `where` really is a range

Recall lesson 3's canonical-numerals theorem: value order and shortlex order coincide on a radix's canonical numerals *only* when every digit is a single code point in code-point order. L2 makes that theorem pay rent. **Where the premise holds**, a value cut like `{a..z}[where c..g]` is provably identical to the plain range `{c..g}` -- so the compiler rewrites the digit-walking `where` into the much cheaper range, rather than walking digit positions at runtime for something that was a contiguous interval all along.

| Expression | Rewrites to | Denotes |
| --- | --- | --- |
| `{a..z}[where c..g]` | `{c..g}` | c, d, e, f, g |
| `{0..9}[where 3..7]` | `{3..7}` | 3, 4, 5, 6, 7 |
| `{0..9}[below 3..7]` | `{3..6}` | 3, 4, 5, 6 |
| `{0..9}[where 7..3]` | `{}` | empty (hi below lo) |

The premise is *checked at compile time*, not assumed: every digit the cut takes must be exactly one code point, and those code points must be adjacent in value order. A radix whose digits wear wider faces (`{a,bb}`, lesson 3's own counterexample) or that skips around the code space fails the check and keeps walking digit positions the slow way -- correctly, just not for free. The top-exclusive `below` needs the *whole* cut in hand (it is spelled, in L3, as one cut with another subtracted off, lesson 6), so both halves have to pass the check independently.

This rewrite is a `Program -> Program` step, applied once at `core/contract.py`'s seam -- it runs after compilation and before the engine ever sees the program, so the engine always receives the cheap form when one exists.

## The sentinel boundary

Lesson 4 introduced sentinels as denotationally simple (one entry, one face, a fresh noncharacter) and left the concrete mechanics to this layer, because they are entirely operational:

- **Allocation** -- the host hands out noncharacters starting at U+FDD0, in declaration order. No denotation anywhere reads *which* code point a given sentinel drew; only that it sits outside `char` and apart from every other sentinel.
- **Pool** -- Unicode sets aside exactly 66 noncharacters. A 67th `sentinel` declaration is refused: a finite resource exhausted, the same shape of refusal as a budget (below), even though it is not one of the three named budgets.
- **Ingest** -- a document that arrives already spelling a noncharacter is refused before a script ever touches it. This is the guard that makes the whole masking idiom sound: if the sentinel space could already be present in real input, "invisible tag" would be a lie.
- **Exit strip** -- every declared sentinel's face is stripped from the document when the run finishes, so nothing engine-private ever ships in the output and no script has to remember to clean up after itself.

## Refusals: decline rather than hang or guess

The other half of the contract. Where a read or a run cannot complete within a stated bound, L2 refuses it with a specific diagnostic, rather than letting it hang forever or silently guessing an answer.

| Run | Refused when | Diagnostic |
| --- | --- | --- |
| membership in an unguarded closure -- `{a, &}` on a non-member | no stage settles it, so absence has no bound | `HimarkUnsettledError` |
| a canonical `$0` or factor `$k` read | the wearer sits past the read budget | `HimarkScopeError` |
| a value cut `@lo..hi` over an unbounded head | the radix exceeds the digit budget | `ValueLineError` |
| a match or a contracting pass | it spends past the host's work budget | `HimarkBudgetError` |
| a document at ingest | it spells a noncharacter (the sentinel space) | `HimarkSentinelError` |
| a `sentinel` declaration | the noncharacter pool (66) is exhausted | `HimarkSentinelError` |

Notice `<=>` (lesson 4's contraction) does not get a row of its own. A run that never settles is not a special case -- the iteration is one metered run, so a pass that would spin forever simply spends past the ordinary work budget and is refused there. There is nothing to bound in advance because there is no declared measure to shrink; "settling" *is* "the document stops moving," full stop.

**Guarded, precisely, one more time.** A `&` inside a product is guarded when some sibling factor in that same product cannot spell the empty face -- so every pass through the closure is forced to add at least one real character before it can recurse. `{@x, &@x}`, the shape almost the entire standard library is built from (lesson 6), sits inside this fragment, and decides absence exactly as it always did. Having *some* factor sitting next to the `&` is not the same thing as having a guard -- the sibling specifically has to be unable to spell nothing.

## Two kinds of refusal, and why the distinction is load-bearing

This is worth internalizing on its own, because it is the difference between a rule every engine *must* get right and a rule every engine is free to set for itself:

- **The unsettled refusal is semantic.** An engine that answers "absent" for membership in an unguarded body is not being lenient -- it is *wrong*, the same way an engine that mis-implements the collision rule would be wrong. `static/conformance/denote.json` (lesson 8) pins this by letting a `contains` answer be `true`, `false`, or the literal string `"unsettled"` -- a third possible answer, checked across every engine.
- **The three budgets are host choices.** Their *existence* is part of the contract every engine must honor (something must eventually say "too much work"), but their *size* is not, and no conformance case anywhere fixes a specific number. Your engine can set its own limits; a port in another language is free to pick different ones, and the corpus never asks it to match Python's.

## Where an obligation lives is not where you might guess

A natural assumption is that "L2" means "one module called `contract.py` that does all of this." It does not, and the project is explicit about why: an obligation lands wherever it is actually *enforceable*, and what marks a given refusal as L2's is the *error class it raises*, never the file it happens to live in.

| Obligation | Lives in |
| --- | --- |
| Reach | `core/floor/reach.py`, spent in `denote/split.py` and `scan/match.py` |
| Value-cut collapse | `compiler/valueline.py` (the cut itself) + `core/contract.py` (the paired top-exclusive rewrite) |
| Unguarded-closure membership | `denote/universe.py`, over `floor/binder.settled` |
| Read budget (`$0`/`$k`) | `scan/capture.py` |
| Digit budget (a value cut) | `compiler/valueline.py` |
| Work budget (a scan, a `<=>`) | `engine/budget.py` |
| Sentinel pool and ingest | `compiler/resolve.py`, `core/contract.py` |

`core/contract.py` really is L2's *seam* -- the one `Program -> Program` rewrite step and the one ingest check that has an actual call site in the pipeline -- but it is not L2's whole implementation. Lesson 7 walks the pipeline these modules sit in and shows exactly where each of these obligations is checked at runtime.

## What you should now be able to say

- L2 exists because L1 is total and L1.5 adds no rejection either, yet execution still has to finish: it is the layer that prices work and refuses what has no bound.
- Reach is an upper bound read directly off an expression's shape, narrowing both the product-split search and the text scan without changing any answer.
- The value-cut collapse cashes lesson 3's canonical-numerals theorem: a single-digit value cut is provably a plain range, and the compiler rewrites it to one when the premise checks out.
- Five refusals cover an unguarded closure, a read past budget, a digit budget over a value cut, a work budget over a run, and both edges of the sentinel boundary -- and a non-settling `<=>` is just the work budget, not a sixth case.
- The unsettled refusal is semantic (every engine must agree); the three budgets are host choices (no engine has to match another's numbers).
- L2's obligations are scattered across the modules where they are enforceable, identified by error class, not gathered into one file.

Next: L3, the standard library -- a handful of `uni`/`def` declarations written entirely over the L1.5 surface, which is where all of this finally starts looking like a language you would want to use.
