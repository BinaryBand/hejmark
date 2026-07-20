/- L1 bridge: the split address space -- product and union term shapes with
their denotation inversions.

`docs/foundation/L1.md` (Positional value) orders a product's entries by
mixed-radix positional value, most significant factor first, and settles
every collision by one rule: "a spelling is claimed by the least
`<value, face>` address that spells it ... and every later claimant drops
it". `L1/Order/Collision.lean` proves that ownership rule well-defined over
an abstract address space and `L1/Order/Collapse.lean` computes what
survives it over abstract pairs; this file lands both on the real syntax:
the addresses are the actual cuts `s = p ++ q` that `Semantics.lean`'s
`fsplit` ranges over to denote a product, positional order is the
lexicographic spelling order on those cuts (prefix most significant), and
an entry is owned by its least cut.

The load-bearing fact is that a `prod` wrapper never binds: `freeAmpb`
detects only a literal `&` factor and never recurses into a brace factor
(`Syntax.lean`'s binder-detection comment -- the fold's own braces are the
innermost binder site), so `prod2 a b` is a non-binder even when a factor
(e.g. `unitClosure`) is itself a binder, and the denotation inversion
`prod2_denotes_iff` is unconditional -- `fsplit` hands each factor exactly
its own `denotes`.

On the union side (`docs/foundation/L1.md`, Union `,`: "append a universe's
entries, in its order, skipping any already present") this file supplies the
inversion `denotes_napp_iff` and the bracing move the union enumeration is
built on. The inversion carries honest hypotheses: both bodies non-binders
(a binder operand enters by bracing it once more -- `braced`, the doc's own
move for folding a closure) and the second body subtraction-free (a
subtraction in the second body would strip the first body's faces; one in
the first body acts before the append and is harmless).

`someSplitP` is the one split-choosing primitive: the `splitLt`-least cut of
a spelling into pieces satisfying two predicates, junk when none exists. The
`denotes`-specialization `someSplit` is what the product recursions and the
transfinite rows use; the within-stage recursion in `RecOrder.lean`
instantiates `someSplitP` directly on `walk`/`amp` piece predicates.

- `prod2_collision_settled`: the collision rule settles on real product
  syntax -- every denoted spelling has a unique least split,
  `collision_settled`'s content with real cuts for addresses.

The entry orders themselves and their ordinal types live in `RecOrder.lean`'s
body-recursive order (`entryRecType_prod2`, the positional product law;
`entryRecType_napp` / `entryRecType_napp_disjoint`, the union laws), which
recurses into each factor and body rather than ordering them by raw
shortlex; the transfinite rows built on them are in `L1/Bridge/Rows.lean`. -/
import L1.Bridge.Entries

namespace L1

open Ordinal

/- ---------------------------------------------------------------- -/
/- Split addresses and their positional order.                       -/
/- ---------------------------------------------------------------- -/

/-- Positional order on split addresses: lexicographic on the pieces,
prefix most significant -- the `<value, value>` reading of the doc's mixed
radix, with spelling order for value order. -/
abbrev splitLt : Spelling × Spelling → Spelling × Spelling → Prop :=
  Prod.Lex (List.Shortlex ((· < ·) : Code → Code → Prop))
    (List.Shortlex ((· < ·) : Code → Code → Prop))

/-- A split address: `s` cut into a head that `a` denotes and a tail that `b`
denotes -- the real cuts `fsplit` ranges over. Used both for the binary
`prod2` and, off the 2-factor case, for the `Factors` recursion's head/tail
cut in `RecOrder.lean`. -/
def IsSplit (a b : Node) (s : Spelling) (pq : Spelling × Spelling) : Prop :=
  s = pq.1 ++ pq.2 ∧ denotes a pq.1 ∧ denotes b pq.2

/- ---------------------------------------------------------------- -/
/- The one split-choosing primitive.                                 -/
/- ---------------------------------------------------------------- -/

open Classical in
/-- The sole split-choosing primitive: the least split of `s` into `p ++ q`
with `headP p` and `tailP q`, junk `([], [])` when none. The product
recursions and transfinite rows use it through the `denotes`-specialization
`someSplit` below; the within-stage product recursion instantiates it
directly on `walk`/`amp` piece predicates rather than `denotes`. -/
noncomputable def someSplitP (headP tailP : Spelling → Prop) (s : Spelling) :
    Spelling × Spelling :=
  if h : ∃ pq : Spelling × Spelling, s = pq.1 ++ pq.2 ∧ headP pq.1 ∧ tailP pq.2
  then (IsWellFounded.wf (r := splitLt)).min _ h
  else ([], [])

/-- The chosen split is a genuine one whenever any exists. -/
theorem someSplitP_spec (headP tailP : Spelling → Prop) (s : Spelling)
    (h : ∃ pq : Spelling × Spelling, s = pq.1 ++ pq.2 ∧ headP pq.1 ∧ tailP pq.2) :
    s = (someSplitP headP tailP s).1 ++ (someSplitP headP tailP s).2
      ∧ headP (someSplitP headP tailP s).1 ∧ tailP (someSplitP headP tailP s).2 := by
  rw [someSplitP, dif_pos h]
  exact WellFounded.min_mem _ _ h

/-- The chosen split depends on the piece predicates only through what they
mean, not how they are written. The two product recursions carve their pieces
with different but pointwise-equivalent predicates -- `denotes` on one side,
`ndenote` / `fsplit` over the empty amp-set on the other -- so reconciling them
is exactly this congruence. -/
theorem someSplitP_congr {headP₁ headP₂ tailP₁ tailP₂ : Spelling → Prop}
    (hh : ∀ p, headP₁ p ↔ headP₂ p) (ht : ∀ q, tailP₁ q ↔ tailP₂ q) (s : Spelling) :
    someSplitP headP₁ tailP₁ s = someSplitP headP₂ tailP₂ s := by
  have h1 : headP₁ = headP₂ := funext fun p => propext (hh p)
  have h2 : tailP₁ = tailP₂ := funext fun q => propext (ht q)
  rw [h1, h2]

/-- Some owning split of `s` into head/tail (junk `([], [])` when none): the
`denotes`-specialization of `someSplitP` the product recursions and the rows
use; on a real non-binder product entry it is the least split owning the
entry. -/
noncomputable def someSplit (nh nt : Node) (s : Spelling) : Spelling × Spelling :=
  someSplitP (denotes nh) (denotes nt) s

/-- The total `someSplit` picks a genuine owning split whenever one exists. -/
theorem someSplit_isHT (nh nt : Node) (s : Spelling) (h : ∃ pq, IsSplit nh nt s pq) :
    IsSplit nh nt s (someSplit nh nt s) :=
  someSplitP_spec (denotes nh) (denotes nt) s h

/-- Nothing splits earlier than the chosen split: the ownership half of the
collision rule ("every later claimant drops it"). -/
theorem someSplit_not_lt (nh nt : Node) (s : Spelling) {pq : Spelling × Spelling}
    (h : IsSplit nh nt s pq) : ¬ splitLt pq (someSplit nh nt s) := by
  have hex : ∃ pq' : Spelling × Spelling,
      s = pq'.1 ++ pq'.2 ∧ denotes nh pq'.1 ∧ denotes nt pq'.2 := ⟨pq, h⟩
  rw [someSplit, someSplitP, dif_pos hex]
  exact WellFounded.not_lt_min (IsWellFounded.wf (r := splitLt))
    {pq' | s = pq'.1 ++ pq'.2 ∧ denotes nh pq'.1 ∧ denotes nt pq'.2} h

/-- Pin the owner: a split that every other split equals-or-follows is the one
`someSplit` picks. Every concrete row computes its owner through this. -/
theorem someSplit_eq (nh nt : Node) {s : Spelling} {pq : Spelling × Spelling}
    (hmem : IsSplit nh nt s pq)
    (hleast : ∀ pq', IsSplit nh nt s pq' → pq' = pq ∨ splitLt pq pq') :
    someSplit nh nt s = pq := by
  have hex : ∃ pq' : Spelling × Spelling,
      s = pq'.1 ++ pq'.2 ∧ denotes nh pq'.1 ∧ denotes nt pq'.2 := ⟨pq, hmem⟩
  rw [someSplit, someSplitP, dif_pos hex]
  rcases hleast _ (WellFounded.min_mem (IsWellFounded.wf (r := splitLt))
      {pq' | s = pq'.1 ++ pq'.2 ∧ denotes nh pq'.1 ∧ denotes nt pq'.2} hex) with h | h
  · exact h
  · exact absurd h (WellFounded.not_lt_min (IsWellFounded.wf (r := splitLt))
      {pq' | s = pq'.1 ++ pq'.2 ∧ denotes nh pq'.1 ∧ denotes nt pq'.2} hmem)

/- ---------------------------------------------------------------- -/
/- The binary product and its unconditional inversion.               -/
/- ---------------------------------------------------------------- -/

/-- Binary product on real syntax: one `prod` member with two brace
factors. -/
def prod2 (a b : Node) : Node := nsingle (.prod (.node a (.node b .nil)))

/-- A `prod` wrapper never binds: a free `&` is only ever a literal `&`
factor, and a brace factor keeps its binders to itself. -/
theorem prod2_bindsb (a b : Node) : bindsb (prod2 a b) = false := rfl

/-- The load-bearing inversion, unconditional -- binder factors included: a
binary product wears exactly the concatenations of its factors' spellings. -/
theorem prod2_denotes_iff (a b : Node) (s : Spelling) :
    denotes (prod2 a b) s ↔ ∃ p q, s = p ++ q ∧ denotes a p ∧ denotes b q := by
  have h : denotes (prod2 a b) s
      ↔ fsplit (.node a (.node b .nil)) (fun _ => False) s := by
    show ndenote (prod2 a b) (fun _ => False) s ↔ _
    rw [ndenote_nonbinder _ _ _ (prod2_bindsb a b)]
    show walk (nsingle (.prod (.node a (.node b .nil)))) _ False s ↔ _
    rw [walk_single_prod, false_or]
  rw [h, fsplit_fnode]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    rw [fsplit_fnode] at hq
    obtain ⟨p', q', rfl, hq', hnil⟩ := hq
    rw [fsplit_fnil] at hnil
    subst hnil
    exact ⟨p, p', by rw [List.append_nil], hp, hq'⟩
  · rintro ⟨p, q, rfl, hp, hq⟩
    refine ⟨p, q, rfl, hp, ?_⟩
    rw [fsplit_fnode]
    exact ⟨q, [], (List.append_nil q).symm, hq, by rw [fsplit_fnil]⟩

theorem isSplit_of_denotes {a b : Node} {s : Spelling}
    (h : denotes (prod2 a b) s) : ∃ pq, IsSplit a b s pq := by
  obtain ⟨p, q, rfl, hp, hq⟩ := (prod2_denotes_iff a b _).mp h
  exact ⟨(p, q), rfl, hp, hq⟩

/- ---------------------------------------------------------------- -/
/- Collision ownership: the least split claims the spelling.         -/
/- ---------------------------------------------------------------- -/

/-- Headline: the collision rule settles on real product syntax -- every
denoted spelling of a binary product is claimed by a unique least split
address. `collision_settled` proved the rule well-defined over abstract
`<value, face>` addresses; here the addresses are the real cuts `fsplit`
ranges over, and the claimant is the one `someSplit` picks. -/
theorem prod2_collision_settled (a b : Node) (s : Spelling)
    (h : denotes (prod2 a b) s) :
    ∃! pq, IsSplit a b s pq
      ∧ ∀ pq', IsSplit a b s pq' → pq' = pq ∨ splitLt pq pq' := by
  have hex := isSplit_of_denotes h
  refine ⟨someSplit a b s, ⟨someSplit_isHT a b s hex, ?_⟩, ?_⟩
  · intro pq' h'
    rcases trichotomous_of splitLt pq' (someSplit a b s) with hlt | heq | hgt
    · exact absurd hlt (someSplit_not_lt a b s h')
    · exact Or.inl heq
    · exact Or.inr hgt
  · rintro pq ⟨hmem, hleast⟩
    exact (someSplit_eq a b hmem hleast).symm

/- ---------------------------------------------------------------- -/
/- N-ary product: head/tail piece extraction. The `Factors` recursion -/
/- splits a product entry into its head factor and the tail product,  -/
/- one binary cut at a time, over the same `IsSplit` address the      -/
/- binary `prod2` uses, reused off the 2-factor case.                 -/
/- ---------------------------------------------------------------- -/

/-- A product over a factor list, as a node. -/
def prodNode (fs : Factors) : Node := nsingle (.prod fs)

theorem prodNode_bindsb (fs : Factors) : bindsb (prodNode fs) = hasAmpb fs := by
  simp [prodNode, nsingle, bindsb, freeAmpb]

/-- A non-binder product's denotation is its factor split. -/
theorem denotes_prodNode_fsplit (fs : Factors) (hnb : hasAmpb fs = false)
    (s : Spelling) :
    denotes (prodNode fs) s ↔ fsplit fs (fun _ => False) s := by
  show ndenote (prodNode fs) (fun _ => False) s ↔ _
  rw [ndenote_nonbinder _ _ _ (by rw [prodNode_bindsb, hnb])]
  show walk (nsingle (.prod fs)) _ False s ↔ _
  rw [walk_single_prod, false_or]

/-- Head/tail split characterization for a non-binder product: `n :: rest` wears
exactly the concatenations of `n`'s spellings with `prodNode rest`'s -- an
unconditional binary split of head vs tail over the non-binder skeleton (a
literal `&` in a later factor would make the product bind, so the hypothesis
`hasAmpb rest = false` is exactly the non-binder condition). -/
theorem prodNode_node_split (n : Node) (rest : Factors) (hnb : hasAmpb rest = false)
    (s : Spelling) :
    denotes (prodNode (.node n rest)) s
      ↔ ∃ p q, s = p ++ q ∧ denotes n p ∧ denotes (prodNode rest) q := by
  rw [denotes_prodNode_fsplit (.node n rest) (by simpa [hasAmpb] using hnb),
    fsplit_fnode]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    exact ⟨p, q, rfl, hp, (denotes_prodNode_fsplit rest hnb q).mpr hq⟩
  · rintro ⟨p, q, rfl, hp, hq⟩
    exact ⟨p, q, rfl, hp, (denotes_prodNode_fsplit rest hnb q).mp hq⟩

/-- Every entry of a non-binder product `n :: rest` owns a head/tail split. -/
theorem prodNode_node_split_exists {n : Node} {rest : Factors}
    (hnb : hasAmpb rest = false) (e : Entries (nsingle (.prod (.node n rest)))) :
    ∃ pq, IsSplit n (prodNode rest) e.1 pq := by
  obtain ⟨p, q, hpq, hp, hq⟩ := (prodNode_node_split n rest hnb e.1).mp e.2
  exact ⟨(p, q), hpq, hp, hq⟩

/- ---------------------------------------------------------------- -/
/- Bracing: how a binder enters a union.                             -/
/- ---------------------------------------------------------------- -/

/-- Brace a binder once more: a non-binder wrapper wearing exactly the
closure -- the doc's "to fold a closure, brace it once more". -/
def braced (n : Node) : Node := nsingle (.fold n)

theorem braced_bindsb (n : Node) : bindsb (braced n) = false := rfl

theorem braced_denotes_iff (n : Node) (hb : bindsb n = true) (s : Spelling) :
    denotes (braced n) s ↔ denotes n s := by
  show ndenote (braced n) (fun _ => False) s ↔ _
  rw [ndenote_nonbinder _ _ _ (braced_bindsb n)]
  show walk (nsingle (.fold n)) _ False s ↔ _
  rw [walk_single_fold, false_or, spells_fold_binder n _ s hb]
  exact (ndenote_binder n _ s hb).symm

/- ---------------------------------------------------------------- -/
/- The union inversion, with its honest hypotheses.                  -/
/- ---------------------------------------------------------------- -/

/-- A union of non-binders with a subtraction-free second body wears
exactly the two bodies' spellings. -/
theorem denotes_napp_iff (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hsf2 : subfreeb n2 = true) (s : Spelling) :
    denotes (napp n1 n2) s ↔ denotes n1 s ∨ denotes n2 s := by
  have hb : bindsb (napp n1 n2) = false := by rw [bindsb_napp, hb1, hb2]; rfl
  simp only [denotes]
  rw [ndenote_nonbinder _ _ _ hb, ndenote_nonbinder _ _ _ hb1,
    ndenote_nonbinder _ _ _ hb2, walk_app,
    walk_adds n2 (fun _ => False) (walk n1 (fun _ => False) False s) s hsf2,
    walk_adds n2 (fun _ => False) False s hsf2]
  tauto

end L1
