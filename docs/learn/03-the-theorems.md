# Lesson 3: The theorems -- what the object forces

The constructors are the verbs. The theorems are the *consequences* -- facts about universes that nobody chose, that fall out the moment you fix the object and the five ways to build it. This is the hardest lesson and the one that pays off most, because once you see that positional value, canonical numerals, and the transfinite reach are *forced*, the terse foundation prose stops reading like arbitrary rules and starts reading like arithmetic.

We need one piece of new math first, because two of the five theorems are about *how big* a universe can get, and "how big" here means something stronger than a number.

## A gentle tour of ordinals

You can count entries with the naturals $0, 1, 2, \ldots$ as long as there are finitely many. But an unbounded universe -- `{{{}},&C}`, the closure of the unit under every code point, lesson 2's closing section -- has infinitely many entries, in a definite *order* (the empty spelling, then `a`, then `b`, ..., then `aa`, ...), and we want to talk about that order's "type" -- its shape as a well-order. That is what an **ordinal** is: a canonical representative of a way of well-ordering things. Do not overthink it; build the ladder rung by rung.

- The finite ordinals are just $0, 1, 2, 3, \ldots$ -- the shapes of finite ordered lists. `{}` has type $0$, `{{}}` (the unit) has type $1$, `{a,b,c}` has type $3$.
- $\omega$ (omega) is the first *infinite* ordinal: the order type of the natural numbers $0 < 1 < 2 < \cdots$. It is the shape of "an unbounded sequence with a definite start and no top." `{a,b,&{a,b}}` -- the nonempty `ab`-strings -- has type $\omega$; the spec abbreviates this expression `N` when it needs to write it more than once, and this lesson borrows that habit below. The defining feature of $\omega$: every element has only *finitely many* things below it, but the whole thing is infinite.
- $\omega + 1$, $\omega + 2$, ... : put something *after* all of $\omega$. Picture the naturals, then one extra element sitting beyond every one of them. That last element has infinitely many predecessors -- that is what makes the type bigger than $\omega$.
- $\omega \cdot 2$ (omega times two): two full copies of $\omega$ laid end to end -- $0, 1, 2, \ldots$ then $0', 1', 2', \ldots$. This is the type of `{b,c}N`: the `b`-block `ba, bb, baa, ...` (a full $\omega$) followed by the `c`-block `ca, cb, caa, ...` (another full $\omega$).
- $\omega^2$ (omega squared): $\omega$ copies of $\omega$ -- an unbounded sequence *of* unbounded sequences. `{b}N{b}N` reaches this.
- $\omega^\omega$, then towers, then... $\varepsilon_0$ (epsilon-nought): the first ordinal so large that $\omega^{\varepsilon_0} = \varepsilon_0$ -- it is the limit of the tower $\omega, \omega^\omega, \omega^{\omega^\omega}, \ldots$. It is still *countable* (you could in principle list all its elements), just unimaginably tall. It is the exact ceiling L1 lives under, and we will see why.

Two facts about ordinal arithmetic that will bite you if you assume they work like normal numbers:

- **Addition is not commutative.** $1 + \omega = \omega$ (stick one thing *before* the naturals -- still just the naturals reordered), but $\omega + 1 > \omega$ (stick one thing *after* -- genuinely bigger). *Where* you add matters.
- **Multiplication is not commutative either, and left-multiplication by a finite collapses.** $2 \cdot \omega = \omega$ (two-element blocks, $\omega$ of them -- still type $\omega$), but $\omega \cdot 2 > \omega$ ($\omega$-blocks, two of them). This asymmetry is the whole reason positional value has to be careful about which factor goes on the left.

That is enough. You do not need to compute with ordinals to read the proofs; you need to believe that "how many entries, in what order" has a *type*, that the types form a ladder reaching up to $\varepsilon_0$, and that arithmetic on them is order-sensitive.

## Theorem 1: Positional value (and the one collision rule)

**The claim.** A product's entries are tuples, and each tuple sits at a definite position computed like a number in a *mixed-radix* numeral system. For a tuple $p_0 p_1 \ldots p_{k-1}$ over factors whose order types are $b_0, b_1, \ldots, b_{k-1}$, the position is

$$\sum_i W_i \cdot \mathrm{value}(p_i), \qquad W_i = b_{k-1} \cdot b_{k-2} \cdots b_{i+1}$$

-- the value of component $i$ times the product of all the radices to its *right*, summed most-significant term first. If that looks like how you read a decimal number, it is exactly that, only each digit may have its own base.

**The parable.** A car odometer is fixed-radix: every wheel is base 10, so position $= d_2 \cdot 100 + d_1 \cdot 10 + d_0$. Now imagine a clock: days-hours-minutes-seconds is *mixed* radix -- the seconds wheel is base 60, the hours wheel base 24. To turn "2 days, 3 hours, 4 minutes" into a single number of minutes you multiply each digit by the product of the wheel-sizes to its right. Hejmark's product is that clock. Factor $i$'s "wheel size" is its order type $b_i$, and a tuple's positional value is the reading on the combined odometer. When all factors are finite, all the $b_i$ are naturals, the product $b_{k-1} \cdots b_0$ is a natural, and *the whole product universe has that many entries in exactly that order.* "Finite factors give naturals," and because the count is a plain product of naturals, the *order in which you multiply the factors is invisible to the count* -- $2 \times 3$ and $3 \times 2$ are both $6$.

**Where it gets sharp: an infinite factor.** Put $\omega$ into a factor and the mixed-radix reading uses ordinal arithmetic, where "the order of multiplication is invisible" *fails* -- and it fails in a load-bearing way. Recall $n \cdot \omega = \omega$: any finite digit placed to the *left* of an $\omega$ gets swallowed. That is not a bug to route around; it is the content of rows like `NN` collapsing to type $\omega \cdot k$ rather than $\omega^2$ (theorem 3 works this example in full). The arithmetic is telling you something true about how the spellings actually line up. The face axis composes identically over per-entry face counts, and collides by the same no-op.

**The collision rule, at last stated exactly.** Concatenation is not injective: two different tuples can spell the same string. `{a,ab}{c,bc}` spells `abc` both as `(a, bc)` (positional value 1) and as `(ab, c)` (positional value 2). Both tuples want the spelling `abc`. Who gets it? **One rule settles every collision, within an entry and across entries alike: a spelling is claimed by the least `<value, face>` address that spells it -- value first, face index to break the tie -- and every later claimant drops it.** So `abc` goes to `(a, bc)` at value 1, and `(ab, c)` at value 2 loses that spelling. This is the *same* drop that fold performs and the *same* skip that union performs; it is one mechanism wearing three names.

Three flavors of collision, all the one rule:

- **Within one entry** (same value, different face): lower face index wins. `Z^2`, written `{{{},0}}{{{},0}}`, can spell `0` two ways (left fill writes it, right fill writes it) at the same value; the lower face index keeps it.
- **Across entries** (different values): lower value wins. `{a,ab}{c,bc}`, above. The higher-valued tuple drops the shared spelling.
- **Cross-axis** (a lower value beats a *lower* face index on the other axis): value dominates the face axis, and here is the warning that catches everyone -- *a canonical face can be the one that drops.* In `{{{},0}}{0,00}`, the spelling `00` is claimed by both the value-0 entry (as its face) and the value-1 entry (as *its canonical, index-0* face). Value dominates, so the value-1 entry loses its index-0 face and ends up canonically spelled `000` instead. Surviving faces renumber, so "canonical = index 0" still holds -- it just now names a different spelling.

Rank (positional value) and order type need not agree with plain membership once collisions land: concatenation is not injective, and membership survives the drop where a naive rank count would not. This is exactly the theorem that lesson 11's `Collision.lean` mechanizes, modeling the `<value, face>` address as an ordinal-paired-with-a-natural under lexicographic (dictionary) order, and proving that because that order is a *well-order*, every spelling has a *unique* least claimant -- so ownership is a well-defined function and nothing is owned twice.

:pencil: **Exercise.** Compute the four positional values of `{a,ab}{b,c}` and confirm they are $0,1,2,3$ with no collisions. Then do `{a,ab}{c,bc}` and find the collision. (Answer: in the first, the four spellings `ab, ac, abb, abc` are all distinct, so values $0,1,2,3$ stand. In the second, `(a,bc)` = `abc` at value 1 and `(ab,c)` = `abc` at value 2 collide; the survivors are `ac, abc, abbc`.)

## Theorem 2: Canonical numerals

This one is newer than the other four, and it earns its keep by explaining *why* `where 8..12` can rewrite to the plain range `{8..12}` -- a question you will hit again in lesson 4 (the surface's `where`) and lesson 5 (L2's value-cut collapse rewrite).

**The claim.** Two different orders -- *value* order (position in the dictionary) and *spelling* order (shortlex, character by character) -- agree on the canonical numerals of a radix, and they do so in two stages: one fact is free, one needs premises.

- **Free, for every radix.** Take the numerals closure of any head -- `{0,{1..9,&{0..9}}}` is the north-star example for decimal, but the shape works for any digit alphabet. **First-appearance order under that closure is always value order.** This needs nothing about the digits' spellings: stage-major accumulation walks the widths in order (all width-1 numerals, then all width-2, ...), and within a width, product order walks the digits in value order. No premise about spellings entering at all.
- **Premised, and this is the sharp part.** *Only when* every digit face is a single code point *and* the digits stand in code-point order (a bounded range is both, by construction) do value order and *spelling* order also coincide on that radix's canonical numerals. Two facts do the work: no numeral has a leading zero digit, so a wider numeral is always the larger value (`10 > 9`); and within one width, positional order reads digit by digit, which is exactly shortlex's own tie-break rule.

Only under the premises does the value line arrive shortlex-sorted, which is what lets a spelling range cut it exactly. Both premises genuinely bite -- this is not a formality you can always assume:

- A digit wearing a *wider* face parts the two orders. `{a,bb}` -- where the second digit is spelled with two characters -- ranked by value gives `a, bb, bba, bbbb, ...`; sorted by shortlex you would expect `bbaa` before `bbbb` on spelling grounds, but `bbaa` is value 4, shortlex-below `bbbb` yet not in the value-ordered range at all. Value order and spelling order have quietly diverged.
- A digit list that skips around the code space also fails: `{a,c,e}` as a radix has digits in code-point order but with gaps, which is fine for the *value*-order half but shows why you cannot casually assume any old alphabet is "range-shaped."

The payoff for you as a reader: whenever you see `where lo..hi` compile down to a plain `{lo..hi}` range, this theorem is *why* that is a meaning-preserving move rather than a coincidence -- and whenever it does not (a hex-like radix with multi-character digits, say), you now know exactly which premise failed.

## Theorem 3: Bounded transfinitude

**The claim.** Every universe's order type is an ordinal *below* $\varepsilon_0$, and the constructors are closed under this -- none of them can escape the ceiling. Moreover the ceiling is *stratified*: you do not get near $\varepsilon_0$ until closure starts nesting nonlinearly.

Why closed, in one breath: union adds, subtraction and collision only shrink, fold collapses to exactly one entry, product multiplies at most, and closure sums $\omega$ stages. Each of those operations, applied to types already below $\varepsilon_0$, stays below $\varepsilon_0$ -- because every expression is *finite*, so you only ever apply finitely many of them, and a finite climb from below the bound cannot reach it.

The strata are worth knowing because they map onto how expressive your expression is:

- **Below closure:** you live below $\omega^\omega$. Union alone gives $\omega$ plus a finite tail. Product climbs: `{b,c}N` is $\omega \cdot 2$, `{b}N{b}N` is $\omega^2$ (recall `N` = `{a,b,&{a,b}}`, the nonempty `ab`-strings).
- **Linear closure** (at most one `&` per product, and its co-factors finite): still below $\omega^\omega$. Each stage just multiplies the previous by a finite on the right, so the limit is at most $u \cdot \omega$ for the base's own bound $u$.
- **Nonlinear closure** is what spends the raised ceiling. The showpiece is `{{(}{b}N{)},{(}&&{)}}` -- binary trees over $\omega$ leaves, parenthesized so no two trees collide. The `&&` (two self-references multiplied) *squares* the stage type each pass: $\omega, \omega^2, \omega^4, \ldots$, and the limit is the first universe of order type *exactly* $\omega^\omega$. Nest closures over that and you climb higher, but no *finite* expression ever reaches $\varepsilon_0$, because a closure of stages-below-$\varepsilon_0$ stays below $\varepsilon_0$.

A beautiful subtlety the doc insists on: **collision does not decide the type by itself.** Each drop keeps the least-valued way of splitting a spelling, and it is the *surviving* least splits that fix the type. In `{b}N{b}N` the seams genuinely collide (`babba` splits as both `b|a|b|ba` and `b|ab|b|a`), yet every split whose first segment is `b`-free is its own unique least split, and there are cofinally many of those -- so $\omega^2$ survives the collisions. But in `NN` every split is legal, so the least split pins the first segment to a single character: only finitely many full blocks survive, and the type *collapses* to $\omega \cdot k$ for finite $k$ (here $k = 2$, one block per character). Same collision rule, opposite effect on the type, depending on how many least-splits survive.

You do not need to reproduce these computations. The takeaway: L1's universes are transfinite but *bounded*, the bound is $\varepsilon_0$, and how high a given expression climbs is a precise function of how its closures nest. Lesson 11's order-axis proofs mechanize the *bottom* of this ladder rigorously (finite factors give naturals, positional value is mixed radix); the ceiling is mechanized too, over an abstract ordinal calculus: `static/lean/L1/Order/Transfinitude.lean` proves the closure-free floor stays below $\omega^\omega$, that nonlinear closure's squared stages sup to *exactly* $\omega^\omega$, and that the full calculus never reaches $\varepsilon_0$. And the "collision does not decide the type" subtlety above is a pair of theorems in `L1/Order/Collapse.lean`: the `NN` collapse and the seam-row survival, side by side.

## Theorem 4: Fixpoint on settled bodies

Closure denotes on *every* body (totality), but it only earns its familiar name -- "least fixpoint" -- on the well-behaved ones, and only the *even better*-behaved ones let you *decide membership in bounded time*. Two adjectives carve out the good cases:

- An occurrence of `&` is **positive** when no subtraction operand encloses it. (Subtraction flips the direction of "more stages = more stuff," which is what breaks fixpoint reasoning.)
- It is **guarded** when its product holds an `&`-free factor that wears no empty face -- intuitively, when every pass is forced to add *at least one real character* before recursing.

The two payoffs:

- **Positive body => least fixpoint.** Every constructor is *continuous* in a positive slot, so the inflationary stages we built in lesson 2 and the "true" least fixpoint coincide. The staged construction is not an approximation; it lands exactly on the fixpoint.
- **Guarded body => length-bounded settling.** If every pass adds a character, then a spelling of length $L$ can only be produced by stage $L + 1$ at the latest -- after that, all new spellings are longer than $L$ and can never *become* the spelling you are asking about. So membership of any given spelling is *decided at a finite, computable stage.* You do not have to run the closure to infinity to answer "is `abbb` in here"; you run it $L+1$ steps and stop.

That "run $L+1$ steps and stop" is precisely the bound that makes Hejmark's matcher *decidable*, and it is mechanized in `static/lean/L1/Membership/Settling.lean` as the theorem `guarded_settles`. The hard direction -- that stability really does arrive by stage $L+1$ -- is one of the deepest proofs in the tree (lesson 10 sketches its three layers). Unguarded or negative bodies still *denote* (totality is the constructor's, not the fragment's), but they only *semi*-settle: if a spelling is present it will show up eventually, but absence carries no deadline. L1.5 (lesson 4) classifies this as the matcher's settled scope, and L2 (lesson 5) is what actually *refuses* to run a matcher outside it -- the floor itself never refuses anything.

## Theorem 5: Compression, not capability

This is the theorem that keeps the constructor list at five. A pile of convenient notations -- ranges and finite adjacency, and (one layer up, in L1.5) splice, difference, and intersection -- add *no new power*: each one provably expands into the five real constructors. They earn their place on the page the way a `+=` operator earns its place in a programming language: as *load-bearing spelling*, never as new capability.

- **Bounded range:** `{a..z}` lists the finite union of its shortlex interval at expansion time -- no closure spent, ever; a range's endpoints must be attained spellings of a closure-free (hence finite) operand, which is exactly why the old open-ended `{a..}` had to go (lesson 2's closing section) rather than survive as a limiting case.
- **Finite adjacency:** `{cat}{dog}` = `{catdog}` -- a finite product flattens.
- **Every spelling, generated:** the closure of the unit under the code-point set, `{{{}}, &C}`, is every spelling in shortlex order -- stage $k$ the length-$(k-1)$ spellings, product order breaking ties code point by code point. So the spelling order is **generated, not postulated.** Lesson 10 points you at `unitClosure_generates`, the Lean theorem that proves exactly this.

**The admission test.** Any construct that wants in must enter *either* as compression (expands into the five) *or* as a genuinely new axiom -- never as a special case bolted onto an existing constructor. Only two things sit on the axiom side: **product** (it refuses to compress over an infinite factor) and **closure** (it refuses by *power*). The closure argument is gorgeous and worth carrying: every closure-*free* universe has a *regular* set of faces (a bounded range is a regular language; and union, subtraction, fold, and product all preserve regularity), whereas `{ab, {a}&{b}}` denotes $a^n b^n$, which is famously *not* regular. No arrangement of the closure-free constructors can produce a non-regular face set, so closure adds something none of them can reach. That is a real impossibility proof, the kind that tells you the language's shape is forced rather than chosen -- and the witness half is machine-checked: `static/lean/L1/Membership/Admission.lean`'s `closure_admission` proves the $a^n b^n$ face set is not regular (a Myhill-Nerode argument), on the real semantics. (Closure *can* escape regularity but need not: `{{{}}, &C}` itself is perfectly regular -- it just happens to also be how every range's underlying order gets generated.)

## What you should now be able to say

- Universes have an *order type*, an ordinal; the types climb a ladder from the finite numbers through $\omega$, $\omega \cdot 2$, $\omega^2$, $\omega^\omega$, up to but never reaching $\varepsilon_0$.
- Product positions its tuples by *mixed-radix* positional value; finite factors give plain naturals, an infinite factor makes the ordinal arithmetic (and its non-commutativity) load-bearing.
- Every collision -- within an entry, across entries, cross-axis -- is settled by one rule: least `<value, face>` address wins, later claimants drop, and even a canonical face can be the loser.
- Value order and spelling order agree on a radix's canonical numerals only under two checkable premises (single-code-point digits, in code-point order) -- free by first appearance, premised for shortlex.
- Closure denotes on every body; on *positive* bodies it is the least fixpoint; on *guarded* bodies membership settles by stage $L+1$, which is what makes matching decidable.
- Ranges and adjacency are *compression* -- provably expressible in the five -- so the only true axioms are product and closure, and that minimality is itself a theorem.

Next: we leave the floor. Lesson 4 is L1.5, the surface syntax that turns these five constructors into something you would actually want to write scripts in.
