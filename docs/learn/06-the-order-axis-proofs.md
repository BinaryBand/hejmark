# Lesson 6: The order-axis proofs, up close

This is the payoff. We read the first three order-axis files -- phases A, B, and C of the six -- line by line: `Order.lean`, `Positional.lean`, `Collision.lean`. They are the best proofs to cut your teeth on because each is self-contained (independent of the big membership-axis stack), each proves one clean theorem from lesson 3, and together they walk you up the exact ladder "finite alphabet gives $\omega$" -> "finite product gives a natural" -> "collisions are settled by a well-order."

Reminder from lesson 4: these notes transliterate Lean's Unicode to ASCII. `->` is the arrow, `forall`/`exists`/`exists!` the quantifiers, `<=`/`<` the orders, `x-lex` the lexicographic product, `~=r` an order isomorphism, `(. < .)` the less-than relation as a function. Open the real `.lean` files alongside to see the pretty glyphs; the line numbers below are the real ones.

## The shared strategy, stated once

All three proofs run the *same play* you learned in lesson 4:

1. Define an explicit *numbering* function from the ordered thing to a known model.
2. Prove the numbering *preserves order* (`x < y` maps to `number x < number y`).
3. Prove it is a *bijection* (injective + surjective).
4. Package 1-3 as an order isomorphism (`~=r`).
5. Read off the order type, because order type is invariant under `~=r` and the model's type is known.

`Order.lean` numbers into `Nat` (model for $\omega$). `Positional.lean` numbers into `Fin (bs.prod)` (model for a finite type). `Collision.lean` skips the isomorphism -- it only needs step 1's ordered model to be a *well-order*, then takes a minimum. Watch the play repeat and the files stop looking intimidating.

## `Order.lean`: shortlex over a finite alphabet has type $\omega$

**What it proves (lesson 3, "finite alphabet gives $\omega$").** `Spelling.lean` deliberately used `Code := Nat`, an *infinite* alphabet, so its shortlex was a total order but *not* of type $\omega$ (each length class is itself infinite). This file redoes shortlex over a genuinely finite alphabet `FCode = Fin (m + 1)` -- `m + 1` code points, at least one -- and proves the type is exactly $\omega$. The header (lines 8-9) notes this is *without loss of generality*: any finite, nonempty, linearly ordered alphabet is order-isomorphic to some `Fin (m+1)`.

**The free half: well-order for free from Mathlib** (lines 38-45). Instead of hand-rolling irreflexivity, transitivity, and totality the way `Spelling.lean` did, this file *reuses* Mathlib's `List.Shortlex`:

```
def fshortlex : FSpelling m -> FSpelling m -> Prop := List.Shortlex (. < .)

instance : IsWellFounded (FSpelling m) (fshortlex m) := <List.Shortlex.wf wellFounded_lt>
instance : Std.Trichotomous (fshortlex m)          := List.Shortlex.trichotomous
instance : IsWellOrder (FSpelling m) (fshortlex m) where
```

`IsWellOrder` needs only well-foundedness plus trichotomy; Mathlib supplies both (well-foundedness because `Fin (m+1)`'s order is well-founded, trichotomy because it is linear), and transitivity comes as a derived instance. That empty `where` on the last line is the whole "this is a well-order" proof -- Lean assembles it from the two instances above. This is a lesson in itself: *use the library*. The bespoke `Spelling.lean` proofs were 100+ lines; here it is three.

**The numbering: a base-`(m+1)` odometer with a length offset** (lines 53-63). Shortlex sorts by length first, then dictionary order within a length. So the numbering has two parts:

```
def lenOffset : Nat -> Nat            -- how many spellings are strictly shorter than length k
  | 0     => 0
  | k + 1 => lenOffset k + (m + 1) ^ k

def lexIndex : FSpelling m -> Nat     -- the base-(m+1) numeral of the digits, most-significant first
  | []        => 0
  | a :: rest => a.val * (m + 1) ^ rest.length + lexIndex rest

def value (l : FSpelling m) : Nat := lenOffset m l.length + lexIndex m l
```

Read it against the intuition: all length-$k$ spellings occupy a contiguous block of naturals; `lenOffset k` is where that block *starts* (it counts every shorter spelling: there are $(m+1)^i$ spellings of each length $i$, summed for $i < k$), and `lexIndex` is the offset *within* the block, computed exactly like reading a number in base `m+1`. So `value` = "which block" + "where in the block." This is already the mixed-radix reading `Positional.lean` will generalize -- the header (line 21) flags that `lexIndex` "doubles as a preview of Phase C's positional-value theorem."

**The key bound** (lines 65-75), `lexIndex_lt_pow`: a length-$L$ spelling's `lexIndex` is strictly less than $(m+1)^L$ -- it stays *inside* its block. The proof is induction on the list: peel the leading digit `a` (at most `m`), use the inductive bound on the rest, and let `omega` grind the arithmetic (`hexpand` feeds it the ring identity $(m+1) \cdot p = m \cdot p + p$ so it can finish). This bound is what makes the two halves of `value` not overlap.

**Order preservation** splits exactly along shortlex's own definition:

- Cross-length (lines 92-101), `value_lt_of_length_lt`: a shorter spelling gets a smaller `value`. Proof: `value l1 < lenOffset(len l1 + 1)` (because `lexIndex` stays in-block, the previous bound) `<= lenOffset(len l2)` (because `lenOffset` is strictly monotone and `len l1 < len l2`) `<= value l2`. Three `omega`-glued inequalities.
- Same-length (lines 104-125), `lexIndex_lt_of_lex`: within a length, dictionary order on the digits matches `<` on `lexIndex`. Induction on the `List.Lex` proof, with the interesting case being when the two lists first differ at a digit (`a.val < b.val`): the leading difference dominates because everything to its right is bounded by exactly one place value ($(m+1)^{\text{rest length}}$). Again the bound `lexIndex_lt_pow` is what makes "the high digit wins" rigorous.

`value_strictMono'` (lines 128-135) just glues those two cases via `List.shortlex_def`, and `value_injective` (137-142) is the standard trichotomy argument: if `value l1 = value l2` but `l1 != l2`, one is shortlex-below the other, so its value is strictly smaller -- contradiction. (This is the injective-from-strict-mono trick lesson 4 mentioned.)

**Surjectivity** (lines 151-203): every natural `n` is *some* spelling's value. `ofIndex k r` builds the `k`-digit base-`(m+1)` numeral for `r` (leading digit `(r / (m+1)^k) % (m+1)`, recurse on the remainder). `ofIndex_lexIndex` proves it inverts `lexIndex` when `r` is in range. Then `value_surjective` does the "find the block" step: given `n`, use `Nat.findGreatest` to find the length `k` whose block contains `n` (`lenOffset k <= n < lenOffset (k+1)`), decode `n - lenOffset k` into digits, and confirm the value comes back to `n`. This is the fiddliest proof in the file precisely because "find the right length bracket" is inherently a search; everything downstream is `omega`.

**The payoff** (lines 210-226):

```
noncomputable def valueRelIso : (fshortlex m) ~=r ((. < .) : Nat -> Nat -> Prop) where
  toEquiv     := Equiv.ofBijective (value m) <value_injective m, value_surjective m>
  map_rel_iff' := ...        -- value l1 < value l2  <->  fshortlex l1 l2

theorem finShortlex_type_omega0 : Ordinal.type (fshortlex m) = Ordinal.omega0 := by
  rw [Ordinal.type_eq.mpr <valueRelIso m>]
  exact Ordinal.type_nat_lt
```

Steps 4 and 5 of the shared play: bundle the bijection and order-preservation into `valueRelIso`, then `finShortlex_type_omega0` says the order type equals $\omega$ in two lines -- rewrite by "isomorphic relations have equal type," then invoke `Ordinal.type_nat_lt` (the Mathlib fact that $\omega$ is *by definition* the type of `(Nat, <)`). All the work was in building the iso; the ordinal conclusion is a formality once you have it.

## `Positional.lean`: finite factors give a natural (mixed radix)

**What it proves (lesson 3, theorem 1).** Positional value over a *product* of finite factors is mixed radix, and the product's order type is exactly the natural `bs.prod` (the product of the factor order types). Same play as `Order.lean`, but generalized from a *uniform* base `m+1` to a *per-factor* radix list `bs : List Nat`, and numbering into `Fin (bs.prod)` instead of `Nat`.

**The numbering** (lines 40-43):

```
def mixedRadix : List Nat -> List Nat -> Nat
  | _,      []      => 0
  | [],     _       => 0
  | _b :: bs, d :: ds => d * bs.prod + mixedRadix bs ds
```

This is lesson 3's clock/odometer written as Horner's rule: the leading digit `d` is weighted by `bs.prod` -- the product of *all radices to its right*, which is exactly the doc's weight $W_0 = b_{k-1} \cdots b_1$ -- and the recursion carries the same reading down the tail. If every `bs` were `m+1` this would be `Order.lean`'s `lexIndex`, and indeed the file proves that at the very end (`lexIndex_eq_mixedRadix`, lines 194-200): phase A is the constant-radix special case, tying the two files together.

**Validity as a typed constraint** (lines 47, 131). A tuple is not any digit list -- each digit must be below its factor's radix. Lean expresses "pointwise below" with `List.Forall2 (. < .) ds bs` (the digits and radices agree in length *and* `ds[i] < bs[i]` at every position). A `Tuple bs` is a *subtype*: `{ ds // Forall2 (. < .) ds bs }` -- a digit list bundled with the proof it is valid. This is a recurring Lean idiom: push a side condition into the type so it travels with the value and cannot be forgotten.

**The bound and monotonicity** parallel `Order.lean` exactly:

- `mixedRadix_lt` (47-56): a valid tuple's value lands in `[0, bs.prod)`, so it fits in `Fin bs.prod`. Induction on the `Forall2` proof; the same $(d+1) \cdot p = d\cdot p + p$ ring trick feeds `omega`.
- `mixedRadix_strictMono` (60-84): `List.Lex` order on digits matches `<` on values, the "high digit dominates" argument again, now the leading weight being `bs'.prod` rather than a fixed power.

**Decoding for surjectivity** (93-123): `ofMixed bs r` peels the leading digit `r / bs.prod`, recurses on `r % bs.prod`, and `ofMixed_forall2`/`ofMixed_mixedRadix` prove it produces a *valid* tuple that inverts `mixedRadix`. Same shape as `ofIndex` in `Order.lean`, with division by the running product instead of a fixed power.

**The payoff** (140-184): `toFinVal` sends a tuple to its value in `Fin bs.prod`; `toFinVal_injective` and `toFinVal_surjective` (the trichotomy-and-decode arguments) make it a bijection; `posValueIso` packages it as `~=r` onto `(Fin bs.prod, <)`; and the headline

```
theorem positional_value_type (bs : List Nat) :
    Ordinal.type (tupleLt bs) = (bs.prod : Ordinal) :=
  (Ordinal.type_eq.mpr <posValueIso bs>).trans (Ordinal.type_fin bs.prod)
```

reads: the order type equals `Ordinal.type_fin bs.prod` = the natural `bs.prod`. Because `bs.prod` is a *commutative* `Nat` product, "the order of multiplication is invisible" is immediate -- exactly lesson 3's phrase, now a one-liner corollary of commutativity of `Nat` multiplication.

## `Collision.lean`: least-address ownership is well-defined

**What it proves (lesson 3, the collision rule).** A spelling is owned by the least `<value, face>` address that spells it; every later claimant drops. This file proves that rule is *coherent*: ownership is a well-defined, *unique* function of the spelling, so no spelling is owned twice. It is the shortest of the three because it does not need a full isomorphism -- only a *well-order* to minimize over.

**The address model** (lines 39-44):

```
abbrev Address := Ordinal x-lex Nat        -- <value, face>, lexicographically ordered

def Survives (spell : Address -> S) (a : Address) : Prop :=
  forall a', spell a' = spell a -> a <= a'
```

`Address` is `Ordinal x-lex Nat` -- the *lexicographic* product `Prod.Lex`, so the ordinal `value` dominates and the natural `face` breaks ties, exactly the doc's `<value, face>`. Using a genuine `Ordinal` for the value (not a stand-in finite number) is what makes this faithful to "an ordinal below $\varepsilon_0$"; the proof needs only that ordinals are well-ordered, which they are. A "claim configuration" is any map `spell : Address -> S` sending each address to the spelling that face writes. `Survives a` says `a` is the lex-least address writing `spell a` -- it *owns* its spelling.

**The headline** (lines 53-64):

```
theorem collision_settled (spell : Address -> S) (a : Address) :
    exists! o, Survives spell o /\ spell o = spell a := by
  have wf : WellFounded ((. < .) : Address -> Address -> Prop) := wellFounded_lt
  have hne : ({a' | spell a' = spell a} : Set Address).Nonempty := <a, rfl>
  obtain <o, ho_mem, ho_least> : ... := <wf.min _ hne, wf.min_mem _ hne, fun _ hx => wf.min_le hx>
  ...
  refine <o, <fun a' ha' => ho_least a' (ha'.trans ho_spell), ho_spell>, ?_>
  rintro y <hSy, hy>
  exact le_antisymm (hSy o (ho_spell.trans hy.symm)) (ho_least y hy)
```

This is lesson 4's `WellFounded.min` in action, and it is worth savoring because it is the whole point of the file:

- `wf` : the lex order on `Address` is well-founded -- `wellFounded_lt` supplies it, because *both* factors (`Ordinal` and `Nat`) are well-ordered and a lexicographic product of well-orders is a well-order.
- `hne` : the set of addresses spelling the same string as `a` is nonempty (`a` itself is in it, witnessed by `rfl`).
- `obtain <o, ho_mem, ho_least>` : take the *minimum* of that set. `wf.min` is the least element, `wf.min_mem` proves it is in the set (so `spell o = spell a`), and `wf.min_le` proves everything else in the set is `>= o`. That is the *owner*.
- The `refine`/`rintro`/`le_antisymm` finish uniqueness: any *other* survivor `y` of the same spelling must be both `>= o` (because `o` is least) and `<= o` (because `y` survives, so `y` is least too), hence `y = o`. Antisymmetry of `<=` closes it.

`exists!` -- unique existence -- is the crux. Uniqueness is what makes "ownership" a *function* of the spelling rather than a relation, which is what licenses the renumbering rule "canonical stays index 0": no spelling can be owned by two entries, so recompaction is unambiguous.

**The drop and the three concrete collisions** (lines 68-93):

- `non_owner_drops`: any claimant of an owned spelling *other than the owner* sits strictly above it (`o < a`) -- "every later claimant drops it." One-liner: `lt_of_le_of_ne` (the owner is `<=` by survival, and `!=` by hypothesis).
- `value_dominates`, `face_breaks_tie`, `value_over_face`: three tiny term-mode facts checking the lex order resolves lesson 3's three collision flavors. `value_dominates` (lower value wins regardless of face) cashes the across-entry case `{a,ab}{c,bc}`; `face_breaks_tie` (same value, lower face wins) cashes the within-entry $Z^2$ case; `value_over_face` (a lower value beats a *lower* face index on the other axis) cashes the cross-axis case `{{{},0}}{0,00}`, where a *canonical* face is the one that drops. Each is a single application of `Prod.Lex.toLex_lt_toLex`, the lemma that unfolds lexicographic `<` into "first coordinate smaller, or equal-and-second-smaller."

## Reading these on your own

Concrete next steps to make this stick:

- Open `Order.lean` and trace `value` on a tiny alphabet by hand: with `m = 1` (alphabet `{0, 1}`), compute `value []`, `value [0]`, `value [1]`, `value [0,0]` and confirm they are `0, 1, 2, 3` -- shortlex order made arithmetic. Then check that `lenOffset 1 = 1`, `lenOffset 2 = 3` line up with your blocks.
- In `Positional.lean`, pick `bs = [2, 3]` (a factor of order type 2 times one of order type 3) and compute `mixedRadix [2,3] [d0, d1] = d0 * 3 + d1`; confirm it enumerates `0..5` as the digits range, and that `bs.prod = 6` is the order type.
- In `Collision.lean`, convince yourself `value_over_face` really is the `{{{},0}}{0,00}` row: address `<0, 1>` (value-0 entry, its second face `00`) versus `<1, 0>` (value-1 entry, its canonical face `00`); the lex order puts `<0,1>` first, so the value-1 entry loses its index-0 face. That is the doc's warning that "a canonical face can be the one that drops."
- Run `cd static/lean && lake build` and watch it verify. Then break something -- change a `+` to a `-` in `lexIndex` -- and watch the build fail. There is no better way to feel that these proofs are *load-bearing* than to see the kernel refuse a wrong one.

## What you should now be able to say

- All three order-axis proofs run one play: number the ordered thing into a known model, prove the numbering preserves order and is a bijection, package it as an order isomorphism, read off the ordinal.
- `Order.lean` numbers shortlex spellings into `Nat` (length offset + base-`(m+1)` numeral) to get type $\omega$; `Positional.lean` generalizes to a per-factor radix and numbers into `Fin (bs.prod)` to get the natural product; `Collision.lean` needs only a well-order and takes a `WellFounded.min` to get a unique owner.
- The recurring machinery is: subtypes carrying validity proofs, induction with `omega` grinding the arithmetic, trichotomy turning strict-monotone into injective, and Mathlib's `type_nat_lt`/`type_fin`/`wellFounded_lt` supplying the final ordinal facts.
- Each headline theorem's trust is pinned to the three-axiom kernel base, checked by the CI gate you can run yourself.

That is the first half of the order-axis mechanization, and it is a faithful, machine-checked reflection of lesson 3's math. The remaining phases play the same game at higher altitude -- `Transfinitude.lean` runs the ordinal arithmetic up to the $\varepsilon_0$ ceiling, `Enumeration.lean` pins first appearance inside one limit, `Collapse.lean` proves both halves of "collision alone does not decide the type" -- and `L1/Bridge/` lands everything on real syntax, culminating in `Rows.lean`'s transfinite rows. From here, the natural next reads are `Spelling.lean` (the gentlest membership proofs), then `Transfinitude.lean` (the same self-contained style as this lesson's trio, one rung up), and then `Settling.lean` (the hardest), now that you know the shape of the tree and the tool.
