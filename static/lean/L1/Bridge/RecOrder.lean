/- L1 bridge: the body-recursive within-body order (design in
`RecOrder.design.md`).

This module replaces the sanctioned within-body approximation -- `entrySpellLt`
orders a node's entries by raw shortlex -- with an order that recurses into each
constructor's own structure. It is the upstream primitive the rest of
`L1/Bridge/` is framed onto, so it lands additively: the definitions and their
well-order theory go here first, and `entriesType`/`prodLt`/`unionLt`/`Rows`
migrate onto it one module at a time, every intermediate build green.

This first increment is the reusable core of the design's central move. The
existing bridge files prove `IsWellOrder` by embedding into a `Prod.Lex` of
known well orders; for a recursive order that target is itself recursive and
dependent on which sub-body owns an entry, which is awkward to write. Instead an
order is presented as a rank into the single, non-dependent type `Ordinal`:
`rankLt rank a b := rank a < rank b`. Well-foundedness and transitivity are then
free (they are `<` on `Ordinal`, pulled back), so the entire novelty of the
well-order proof collapses to one obligation -- the rank is injective. The
recursive `entryRank` and its injectivity are the next increment. -/
import L1.Bridge.Product
import L1.Bridge.Union

namespace L1

open Ordinal

/- ---------------------------------------------------------------- -/
/- Rank-into-ordinal orders: well-founded and transitive for free,  -/
/- a well order exactly when the rank is injective.                 -/
/- ---------------------------------------------------------------- -/

namespace RecOrder

variable {α : Type*} (rank : α → Ordinal)

/-- The order a rank induces: compare ranks in the ordinals. -/
def rankLt (a b : α) : Prop := rank a < rank b

/-- Pulled back from a well-founded relation, so well-founded with no
hypotheses on the rank. -/
instance isWellFounded : IsWellFounded α (rankLt rank) :=
  ⟨InvImage.wf rank wellFounded_lt⟩

/-- Pulled back from `<` on `Ordinal`, so transitive with no hypotheses. -/
instance isTrans : IsTrans α (rankLt rank) :=
  ⟨fun _ _ _ h₁ h₂ => lt_trans h₁ h₂⟩

/-- An injective rank is a relation embedding of the induced order into `<` on
the ordinals (the relation condition is definitional). -/
def rankEmb (hinj : Function.Injective rank) :
    rankLt rank ↪r ((· < ·) : Ordinal → Ordinal → Prop) :=
  ⟨⟨rank, hinj⟩, Iff.rfl⟩

/-- The one obligation: an injective rank makes the induced order a well order --
`<` on `Ordinal` is one, and the embedding transports it back. -/
theorem isWellOrder_of_injective (hinj : Function.Injective rank) :
    IsWellOrder α (rankLt rank) :=
  (rankEmb rank hinj).isWellOrder

/- ---------------------------------------------------------------- -/
/- Every well order is already a rank order: its own `typein`.       -/
/- This is the base of the recursion -- a leaf node's entries carry  -/
/- no reordering, so their rank is exactly the ordinal position in   -/
/- the shortlex (spelling) order, `typein (entrySpellLt n)`. The two -/
/- facts below say that recovers the original order on the nose and  -/
/- is injective, so every order the bridge already builds            -/
/- (`entrySpellLt`, `entryLt`, `prodLt`, `unionLt`) is an instance of -/
/- the rank framework, not a competitor to it.                       -/
/- ---------------------------------------------------------------- -/

section Typein

variable {r : α → α → Prop} [IsWellOrder α r]

/-- `typein` is injective on a well order: it is an order iso onto an initial
segment, so distinct elements land at distinct ordinal positions. -/
theorem typein_injective : Function.Injective (Ordinal.typein r) :=
  Ordinal.typein_injective r

/-- The rank order induced by `typein r` is `r` itself -- `typein` reflects and
preserves the order, so nothing is reordered by passing through the ordinals. -/
theorem rankLt_typein_eq : rankLt (Ordinal.typein r) = r := by
  ext a b
  exact Ordinal.typein_lt_typein r

end Typein

end RecOrder

/- ---------------------------------------------------------------- -/
/- Reinterpretation lemmas: route a non-binder entry down into the   -/
/- sub-body that owns it. These are the inputs to `entryRank`'s      -/
/- recursive calls -- each carries an entry of the whole node to an  -/
/- entry (or entries) of a strictly smaller sub-node, and injectively -/
/- so, which is what makes the composed rank injective.               -/
/- ---------------------------------------------------------------- -/

/-- Fold-of-a-non-binder reinterpretation. A fold whose inner universe does
not bind wears exactly inner's language, plus the empty spelling when inner is
denotationally empty -- the fold-to-unit boundary. So a fold-of-non-binder
entry is either an entry of `inner` or the lone empty face of an empty inner;
the recursion routes the former down into `inner` and ranks the latter at 0. -/
theorem denotes_fold_nonbinder (inner : Node) (s : Spelling)
    (h : bindsb inner = false) :
    denotes (nsingle (.fold inner)) s
      ↔ denotes inner s ∨ (s = [] ∧ ∀ t, ¬ denotes inner t) := by
  have hnode : bindsb (nsingle (.fold inner)) = false := by
    simp [nsingle, bindsb, freeAmpb]
  simp only [denotes, ndenote, hnode, h, Bool.false_eq_true, if_false,
    walk_single_fold, false_or, spells_fold]

open Ordinal in
/-- Binary product pieces. An entry of a binary product carries to the pair of
factor entries carved out by its owning split (`leastSplit`). The recursion
recurses `entryRank` into each factor on its piece. -/
noncomputable def prodPieces (a b : Node) (e : Entries (prod2 a b)) :
    Entries a × Entries b :=
  (⟨(leastSplit a b e).1, (leastSplit_isSplit a b e).2.1⟩,
   ⟨(leastSplit a b e).2, (leastSplit_isSplit a b e).2.2⟩)

/-- The pieces map is injective with no uniqueness hypothesis -- the owning
split reconstructs its entry (`e.1 = p ++ q`), so distinct entries cannot share
both pieces. This is the product face of the composed-injectivity argument. -/
theorem prodPieces_injective (a b : Node) :
    Function.Injective (prodPieces a b) := by
  intro x y hxy
  simp only [prodPieces, Prod.mk.injEq, Subtype.mk.injEq] at hxy
  apply Subtype.ext
  rw [(leastSplit_isSplit a b x).1, (leastSplit_isSplit a b y).1, hxy.1, hxy.2]

open Classical in
/-- Union first-owner reinterpretation (subtraction-free bodies). An entry of a
union `napp n1 n2` is owned by the first body when it denotes it, else by the
second; ownership is a function of the spelling (the `dif`), so the map into
`Entries n1 ⊕ Entries n2` is injective. The recursion recurses `entryRank` into
the owning body -- first body's block, then the second body's unclaimed
remainder. Subtraction-free is exactly the hypothesis `denotes_napp_iff`
carries (a subtraction interleaved in the second body would strip the first
body's faces and break the clean block split); interleaved subtraction is a
deferred follow-up increment. -/
noncomputable def unionReinterp (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hsf2 : subfreeb n2 = true)
    (e : Entries (napp n1 n2)) : Entries n1 ⊕ Entries n2 :=
  if h : denotes n1 e.1 then Sum.inl ⟨e.1, h⟩
  else Sum.inr ⟨e.1, ((denotes_napp_iff n1 n2 hb1 hb2 hsf2 e.1).mp e.2).resolve_left h⟩

theorem unionReinterp_injective (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hsf2 : subfreeb n2 = true) :
    Function.Injective (unionReinterp n1 n2 hb1 hb2 hsf2) := by
  intro x y hxy
  simp only [unionReinterp] at hxy
  by_cases hx : denotes n1 x.1 <;> by_cases hy : denotes n1 y.1
  · rw [dif_pos hx, dif_pos hy] at hxy
    simp only [Sum.inl.injEq, Subtype.mk.injEq] at hxy
    exact Subtype.ext hxy
  · rw [dif_pos hx, dif_neg hy] at hxy
    exact absurd hxy Sum.inl_ne_inr
  · rw [dif_neg hx, dif_pos hy] at hxy
    exact absurd hxy Sum.inr_ne_inl
  · rw [dif_neg hx, dif_neg hy] at hxy
    simp only [Sum.inr.injEq, Subtype.mk.injEq] at hxy
    exact Subtype.ext hxy

/- ---------------------------------------------------------------- -/
/- N-ary product: head/tail piece extraction. The `Factors` recursion -/
/- splits a product entry into its head factor and the tail product,  -/
/- one binary cut at a time, so it reuses a general head/tail          -/
/- least-split (generalizing `Product.leastSplit` off the 2-factor     -/
/- `prod2` to any node whose entries split head/tail).                 -/
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

open Ordinal in
/-- Abstract head/tail split address: `s` cut into a head that `nh` denotes and
a tail that `nt` denotes. Generalizes `Product.IsSplit` off the binary `prod2`
to any node whose entries split head/tail. -/
def IsHT (nh nt : Node) (s : Spelling) (pq : Spelling × Spelling) : Prop :=
  s = pq.1 ++ pq.2 ∧ denotes nh pq.1 ∧ denotes nt pq.2

open Ordinal in
/-- The least head/tail split owning an entry, given that every entry of `N`
splits. Generalizes `Product.leastSplit`; positional order `splitLt` is
reused. -/
noncomputable def htLeastSplit (nh nt N : Node)
    (hsplit : ∀ s, denotes N s → ∃ pq, IsHT nh nt s pq)
    (e : Entries N) : Spelling × Spelling :=
  (IsWellFounded.wf (r := splitLt)).min {pq | IsHT nh nt e.1 pq} (hsplit e.1 e.2)

open Ordinal in
theorem htLeastSplit_isHT (nh nt N : Node)
    (hsplit : ∀ s, denotes N s → ∃ pq, IsHT nh nt s pq) (e : Entries N) :
    IsHT nh nt e.1 (htLeastSplit nh nt N hsplit e) :=
  WellFounded.min_mem (IsWellFounded.wf (r := splitLt))
    {pq | IsHT nh nt e.1 pq} (hsplit e.1 e.2)

open Ordinal in
/-- The head/tail pieces of an entry: the factor entries carved by its owning
split. Generalizes `prodPieces`. -/
noncomputable def htPieces (nh nt N : Node)
    (hsplit : ∀ s, denotes N s → ∃ pq, IsHT nh nt s pq) (e : Entries N) :
    Entries nh × Entries nt :=
  (⟨(htLeastSplit nh nt N hsplit e).1, (htLeastSplit_isHT nh nt N hsplit e).2.1⟩,
   ⟨(htLeastSplit nh nt N hsplit e).2, (htLeastSplit_isHT nh nt N hsplit e).2.2⟩)

open Ordinal in
/-- The pieces map is injective with no uniqueness hypothesis -- the owning split
reconstructs the entry (`e.1 = p ++ q`). Generalizes `prodPieces_injective`. -/
theorem htPieces_injective (nh nt N : Node)
    (hsplit : ∀ s, denotes N s → ∃ pq, IsHT nh nt s pq) :
    Function.Injective (htPieces nh nt N hsplit) := by
  intro x y hxy
  simp only [htPieces, Prod.mk.injEq, Subtype.mk.injEq] at hxy
  apply Subtype.ext
  rw [(htLeastSplit_isHT nh nt N hsplit x).1, (htLeastSplit_isHT nh nt N hsplit y).1,
    hxy.1, hxy.2]

/- ---------------------------------------------------------------- -/
/- The rank and bound, defined together in one structural recursion. -/
/- Both are total on every node: reordering constructors compose      -/
/- sub-ranks into disjoint ordinal intervals (rank), whose widths are  -/
/- the bounds; a closure (a binder node, or a fold/prod that binds)    -/
/- ranks by the stage-major `entryLt` fallback; a subtraction adds no  -/
/- entry. Faithfulness (injectivity, the bound invariant) is proved    -/
/- separately over the subtraction-free skeleton -- this is just the   -/
/- definition, so the guards below take the total (Classical) form and -/
/- their junk branches are shown unreachable there.                    -/
/- ---------------------------------------------------------------- -/

/-- Bound for a closure block: the order type of the stage-major fallback
`entryLt`, the already-proven well order every closure ranks by. -/
noncomputable def closureBound (n : Node) : Ordinal := Ordinal.type (entryLt n)

open Classical in
/-- Some owning split of `s` into head/tail (junk `([], [])` when none) -- the
total choice the product recursion uses; on a real non-binder product entry it
is the least split `htLeastSplit` picks. -/
noncomputable def someSplit (nh nt : Node) (s : Spelling) : Spelling × Spelling :=
  if h : ∃ pq, IsHT nh nt s pq then (IsWellFounded.wf (r := splitLt)).min _ h
  else ([], [])

open Classical in
mutual

/-- Rank of an entry of a one-member node. -/
noncomputable def mRank : (m : Member) → Entries (nsingle m) → Ordinal
  | .face t, e => typein (entrySpellLt (nsingle (.face t))) e
  | .range lo hi, e => typein (entrySpellLt (nsingle (.range lo hi))) e
  | .final lo, e => typein (entrySpellLt (nsingle (.final lo))) e
  | .amp, e => typein (entryLt (nsingle .amp)) e
  | .sub inner, e => typein (entrySpellLt (nsingle (.sub inner))) e
  | .fold inner, e =>
      if bindsb inner then typein (entryLt (nsingle (.fold inner))) e
      else if h : denotes inner e.1 then nRank inner ⟨e.1, h⟩ else 0
  | .prod fs, e =>
      if hasAmpb fs then typein (entryLt (nsingle (.prod fs))) e
      else fRank fs e

/-- Rank of an entry of a node (union spine): first-owner, body-major. -/
noncomputable def nRank : (n : Node) → Entries n → Ordinal
  | .nil, e => absurd e.2 (by
      simp only [denotes, ndenote, bindsb, Bool.false_eq_true, if_false, walk_nil]
      exact not_false)
  | .cons m rest, e =>
      if bindsb (.cons m rest) then typein (entryLt (.cons m rest)) e
      else if h : denotes (nsingle m) e.1 then mRank m ⟨e.1, h⟩
           else if h2 : denotes rest e.1 then mBound m + nRank rest ⟨e.1, h2⟩ else 0

/-- Rank of an entry of a product, positional (mixed radix) over factor pieces. -/
noncomputable def fRank : (fs : Factors) → Entries (nsingle (.prod fs)) → Ordinal
  | .nil, e => typein (entrySpellLt (nsingle (.prod .nil))) e
  | .amp rest, e => typein (entryLt (nsingle (.prod (.amp rest)))) e
  | .node n rest, e =>
      if hasAmpb rest then typein (entryLt (nsingle (.prod (.node n rest)))) e
      else
        fBound rest * (if h1 : denotes n (someSplit n (prodNode rest) e.1).1
            then nRank n ⟨_, h1⟩ else 0)
          + (if h2 : denotes (prodNode rest) (someSplit n (prodNode rest) e.1).2
              then fRank rest ⟨_, h2⟩ else 0)

/-- Bound (offset/weight) contributed by a one-member node. -/
noncomputable def mBound : Member → Ordinal
  | .face t => entriesType (nsingle (.face t))
  | .range lo hi => entriesType (nsingle (.range lo hi))
  | .final lo => entriesType (nsingle (.final lo))
  | .amp => closureBound (nsingle .amp)
  | .sub inner => entriesType (nsingle (.sub inner))
  | .fold inner =>
      if bindsb inner then closureBound (nsingle (.fold inner)) else nBound inner + 1
  | .prod fs => if hasAmpb fs then closureBound (nsingle (.prod fs)) else fBound fs

/-- Bound contributed by a node: the sum of its members' block widths. -/
noncomputable def nBound : Node → Ordinal
  | .nil => 0
  | .cons m rest =>
      if bindsb (.cons m rest) then closureBound (.cons m rest) else mBound m + nBound rest

/-- Bound contributed by a product's factor list: the mixed-radix width, tail
base times head count. The head is the major digit (`fRank` ranks an entry as
`fBound rest * headRank + tailRank` with `tailRank < fBound rest`), so the base
`fBound rest` multiplies on the left -- ordinal `*` makes the right factor major,
so `base * count`, not `count * base`, is the width the head ranges over. -/
noncomputable def fBound : Factors → Ordinal
  | .nil => entriesType (nsingle (.prod .nil))
  | .amp rest => closureBound (nsingle (.prod (.amp rest)))
  | .node n rest =>
      if hasAmpb rest then closureBound (nsingle (.prod (.node n rest)))
      else fBound rest * nBound n

end

/-- The body-recursive rank of a node's entries. -/
noncomputable def entryRank (n : Node) : Entries n → Ordinal := nRank n

/-- The body-recursive bound of a node: a strict upper bound for `entryRank`
(the invariant is proved with injectivity). -/
noncomputable def entryBound (n : Node) : Ordinal := nBound n

/-- The body-recursive within-body order: compare entries by their rank. This
is the order that replaces the shortlex approximation `entrySpellLt`. -/
def entryRecLt (n : Node) : Entries n → Entries n → Prop :=
  RecOrder.rankLt (entryRank n)

/-- Well-founded for free (pulled back from `<` on `Ordinal`). -/
instance (n : Node) : IsWellFounded (Entries n) (entryRecLt n) :=
  RecOrder.isWellFounded (entryRank n)

/-- Transitive for free (pulled back from `<` on `Ordinal`). -/
instance (n : Node) : IsTrans (Entries n) (entryRecLt n) :=
  RecOrder.isTrans (entryRank n)


/- ================================================================ -/
/- STEP 2: faithfulness -- injectivity and the bound invariant over  -/
/- the subtraction-free skeleton, giving `IsWellOrder (entryRecLt)`.  -/
/- ================================================================ -/

/-- Bound invariant plus injectivity, bundled: `rank` lands strictly below
`bound` and is injective (so the induced `rankLt` is a well order). -/
def Faithful {β : Type*} (rank : β → Ordinal) (bound : Ordinal) : Prop :=
  (∀ e, rank e < bound) ∧ Function.Injective rank

/-- Any well order's own `typein` is faithful with bound its order type -- the
leaf/closure base case (a leaf ranks by `entrySpellLt`, a closure by `entryLt`,
both bounded by their own order type). -/
theorem faithful_typein {β : Type*} (r : β → β → Prop) [IsWellOrder β r] :
    Faithful (fun e => Ordinal.typein r e) (Ordinal.type r) :=
  ⟨fun e => Ordinal.typein_lt_type r e, Ordinal.typein_injective r⟩

/- ---- Mixed-radix arithmetic: the product-composition core. ---- -/

/-- Mixed-radix bound: a high digit `a < Q` and low digit `b < W` encode as
`W * a + b`, staying below `W * Q`. -/
theorem mixmul_lt {W a b Q : Ordinal} (hb : b < W) (ha : a < Q) :
    W * a + b < W * Q := by
  calc W * a + b < W * a + W := (add_lt_add_iff_left _).2 hb
    _ = W * (a + 1) := (mul_add_one W a).symm
    _ ≤ W * Q := mul_le_mul_right (Order.add_one_le_iff.mpr ha) W

/-- Mixed-radix injectivity: with the low digit below the base, the division
algorithm recovers both digits. -/
theorem mixmul_inj {W a1 b1 a2 b2 : Ordinal} (hW : W ≠ 0)
    (hb1 : b1 < W) (hb2 : b2 < W) (h : W * a1 + b1 = W * a2 + b2) :
    a1 = a2 ∧ b1 = b2 := by
  have e1 : (W * a1 + b1) / W = a1 := by
    rw [mul_add_div _ hW, div_eq_zero_of_lt hb1, add_zero]
  have e2 : (W * a2 + b2) / W = a2 := by
    rw [mul_add_div _ hW, div_eq_zero_of_lt hb2, add_zero]
  have ha : a1 = a2 := by rw [← e1, ← e2, h]
  subst ha
  exact ⟨rfl, (add_left_cancel_iff).1 h⟩

/- ---- The deep subtraction-free skeleton. ---- -/

/- No subtraction anywhere -- the scope of the first faithfulness increment
(an interleaved subtraction breaks the clean union block split, deferred). -/
mutual
def mSubfree : Member → Bool
  | .face _ => true
  | .range _ _ => true
  | .final _ => true
  | .amp => true
  | .sub _ => false
  | .fold inner => nSubfree inner
  | .prod fs => fSubfree fs
def nSubfree : Node → Bool
  | .nil => true
  | .cons m rest => mSubfree m && nSubfree rest
def fSubfree : Factors → Bool
  | .nil => true
  | .amp rest => fSubfree rest
  | .node n rest => nSubfree n && fSubfree rest
end

/-- Deep subtraction-freeness implies the shallow top-level version, so the
union inversion `denotes_napp_iff` applies at every spine step. -/
theorem nSubfree_subfreeb : ∀ (n : Node), nSubfree n = true → subfreeb n = true
  | .nil, _ => rfl
  | .cons m rest, h => by
      have hrest := nSubfree_subfreeb rest
      cases m <;> simp_all [nSubfree, subfreeb, mSubfree]

/- ---- Head/tail split reconstruction for the product recursion. ---- -/

/-- The total `someSplit` picks a genuine owning split whenever one exists. -/
theorem someSplit_isHT (nh nt : Node) (s : Spelling) (h : ∃ pq, IsHT nh nt s pq) :
    IsHT nh nt s (someSplit nh nt s) := by
  rw [someSplit, dif_pos h]
  exact WellFounded.min_mem _ _ h

/-- Every entry of a non-binder product `n :: rest` owns a head/tail split. -/
theorem prodNode_node_split_exists {n : Node} {rest : Factors}
    (hnb : hasAmpb rest = false) (e : Entries (nsingle (.prod (.node n rest)))) :
    ∃ pq, IsHT n (prodNode rest) e.1 pq := by
  obtain ⟨p, q, hpq, hp, hq⟩ := (prodNode_node_split n rest hnb e.1).mp e.2
  exact ⟨(p, q), hpq, hp, hq⟩

/- ---- One-step unfolding lemmas for the recursive (non-binder) branches. ---- -/

theorem nBound_cons_nb {m : Member} {rest : Node} (hb : bindsb (.cons m rest) = false) :
    nBound (.cons m rest) = mBound m + nBound rest := by
  simp only [nBound, hb, Bool.false_eq_true, if_false]

theorem nRank_cons_first {m : Member} {rest : Node} (hb : bindsb (.cons m rest) = false)
    (e : Entries (.cons m rest)) (hd : denotes (nsingle m) e.1) :
    nRank (.cons m rest) e = mRank m ⟨e.1, hd⟩ := by
  simp only [nRank, hb, Bool.false_eq_true, if_false, dif_pos hd]

theorem nRank_cons_rest {m : Member} {rest : Node} (hb : bindsb (.cons m rest) = false)
    (e : Entries (.cons m rest)) (h1 : ¬ denotes (nsingle m) e.1) (hd : denotes rest e.1) :
    nRank (.cons m rest) e = mBound m + nRank rest ⟨e.1, hd⟩ := by
  simp only [nRank, hb, Bool.false_eq_true, if_false, dif_neg h1, dif_pos hd]

theorem fBound_node_nb {n : Node} {rest : Factors} (hnb : hasAmpb rest = false) :
    fBound (.node n rest) = fBound rest * nBound n := by
  simp only [fBound, hnb, Bool.false_eq_true, if_false]

theorem fRank_node_nb {n : Node} {rest : Factors} (hnb : hasAmpb rest = false)
    (e : Entries (nsingle (.prod (.node n rest))))
    (h1 : denotes n (someSplit n (prodNode rest) e.1).1)
    (h2 : denotes (prodNode rest) (someSplit n (prodNode rest) e.1).2) :
    fRank (.node n rest) e
      = fBound rest * nRank n ⟨_, h1⟩ + fRank rest ⟨_, h2⟩ := by
  simp only [fRank, hnb, Bool.false_eq_true, if_false, dif_pos h1, dif_pos h2]

/- ---- The mutual faithfulness theorem. ---- -/

mutual

theorem mFaithful : ∀ (m : Member), mSubfree m = true → Faithful (mRank m) (mBound m)
  | .face t, _ => by simp only [mRank, mBound, entriesType]; exact faithful_typein _
  | .range lo hi, _ => by simp only [mRank, mBound, entriesType]; exact faithful_typein _
  | .final lo, _ => by simp only [mRank, mBound, entriesType]; exact faithful_typein _
  | .amp, _ => by simp only [mRank, mBound, closureBound]; exact faithful_typein _
  | .sub _, h => absurd h (by simp [mSubfree])
  | .fold inner, h => by
      by_cases hb : bindsb inner = true
      · simp only [mRank, mBound, closureBound, hb, if_true]; exact faithful_typein _
      · rw [Bool.not_eq_true] at hb
        have hin : nSubfree inner = true := by simpa only [mSubfree] using h
        obtain ⟨ib, ii⟩ := nFaithful inner hin
        constructor
        · intro e
          simp only [mRank, mBound, hb, Bool.false_eq_true, if_false]
          by_cases hd : denotes inner e.1
          · rw [dif_pos hd]; exact (ib ⟨e.1, hd⟩).trans_le le_self_add
          · rw [dif_neg hd]; exact zero_lt_one.trans_le le_add_self
        · intro x y hxy
          simp only [mRank, hb, Bool.false_eq_true, if_false] at hxy
          have hxc := (denotes_fold_nonbinder inner x.1 hb).mp x.2
          have hyc := (denotes_fold_nonbinder inner y.1 hb).mp y.2
          by_cases hdx : denotes inner x.1 <;> by_cases hdy : denotes inner y.1
          · rw [dif_pos hdx, dif_pos hdy] at hxy
            have hval := congrArg Subtype.val (ii hxy)
            exact Subtype.ext hval
          · exact absurd hdx ((hyc.resolve_left hdy).2 x.1)
          · exact absurd hdy ((hxc.resolve_left hdx).2 y.1)
          · exact Subtype.ext (((hxc.resolve_left hdx).1).trans ((hyc.resolve_left hdy).1).symm)
  | .prod fs, h => by
      by_cases hna : hasAmpb fs = true
      · simp only [mRank, mBound, closureBound, hna, if_true]; exact faithful_typein _
      · rw [Bool.not_eq_true] at hna
        have hfs : fSubfree fs = true := by simpa only [mSubfree] using h
        have hf := fFaithful fs hfs
        constructor
        · intro e; rw [mRank]; simp only [hna, Bool.false_eq_true, if_false]
          rw [mBound]; simp only [hna, Bool.false_eq_true, if_false]; exact hf.1 e
        · intro x y hxy
          rw [mRank, mRank] at hxy; simp only [hna, Bool.false_eq_true, if_false] at hxy
          exact hf.2 hxy

theorem nFaithful : ∀ (n : Node), nSubfree n = true → Faithful (nRank n) (nBound n)
  | .nil, _ => by
      constructor
      · intro e; exact absurd e.2 (by
          simp only [denotes, ndenote, bindsb, Bool.false_eq_true, if_false, walk_nil]; exact not_false)
      · intro x; exact absurd x.2 (by
          simp only [denotes, ndenote, bindsb, Bool.false_eq_true, if_false, walk_nil]; exact not_false)
  | .cons m rest, h => by
      by_cases hb : bindsb (.cons m rest) = true
      · simp only [nRank, nBound, closureBound, hb, if_true]; exact faithful_typein _
      · rw [Bool.not_eq_true] at hb
        have hcomp : mSubfree m = true ∧ nSubfree rest = true := by
          simpa only [nSubfree, Bool.and_eq_true] using h
        have hm : mSubfree m = true := hcomp.1
        have hr : nSubfree rest = true := hcomp.2
        have hbcomp : freeAmpb m = false ∧ bindsb rest = false := by
          rw [bindsb, Bool.or_eq_false_iff] at hb; exact hb
        have hbm : bindsb (nsingle m) = false := by
          simp only [nsingle, bindsb, Bool.or_false]; exact hbcomp.1
        have hbr : bindsb rest = false := hbcomp.2
        have hsf : subfreeb rest = true := nSubfree_subfreeb rest hr
        obtain ⟨mb, mi⟩ := mFaithful m hm
        obtain ⟨nb, ni⟩ := nFaithful rest hr
        have hcase : ∀ e : Entries (.cons m rest),
            (∃ hd : denotes (nsingle m) e.1, nRank (.cons m rest) e = mRank m ⟨e.1, hd⟩) ∨
            (∃ hd : denotes rest e.1, ¬ denotes (nsingle m) e.1 ∧
                nRank (.cons m rest) e = mBound m + nRank rest ⟨e.1, hd⟩) := by
          intro e
          rcases (denotes_napp_iff (nsingle m) rest hbm hbr hsf e.1).mp e.2 with hA | hB
          · exact Or.inl ⟨hA, nRank_cons_first hb e hA⟩
          · by_cases hA : denotes (nsingle m) e.1
            · exact Or.inl ⟨hA, nRank_cons_first hb e hA⟩
            · exact Or.inr ⟨hB, hA, nRank_cons_rest hb e hA hB⟩
        rw [nBound_cons_nb hb]
        constructor
        · intro e
          rcases hcase e with ⟨hd, he⟩ | ⟨hd, _, he⟩
          · rw [he]; exact (mb _).trans_le (le_self_add)
          · rw [he]; exact (add_lt_add_iff_left _).2 (nb _)
        · intro x y hxy
          rcases hcase x with ⟨hdx, hex⟩ | ⟨hdx, hnx, hex⟩ <;>
            rcases hcase y with ⟨hdy, hey⟩ | ⟨hdy, hny, hey⟩
          · rw [hex, hey] at hxy
            have hval := congrArg Subtype.val (mi hxy)
            exact Subtype.ext hval
          · rw [hex, hey] at hxy
            exact absurd hxy (ne_of_lt ((mb _).trans_le le_self_add))
          · rw [hex, hey] at hxy
            exact absurd hxy.symm (ne_of_lt ((mb _).trans_le le_self_add))
          · rw [hex, hey] at hxy
            have hval := congrArg Subtype.val (ni ((add_left_cancel_iff).1 hxy))
            exact Subtype.ext hval

theorem fFaithful : ∀ (fs : Factors), fSubfree fs = true → Faithful (fRank fs) (fBound fs)
  | .nil, _ => by simp only [fRank, fBound, entriesType]; exact faithful_typein _
  | .amp rest, _ => by simp only [fRank, fBound, closureBound]; exact faithful_typein _
  | .node n rest, h => by
      by_cases hna : hasAmpb rest = true
      · simp only [fRank, fBound, closureBound, hna, if_true]; exact faithful_typein _
      · rw [Bool.not_eq_true] at hna
        have hcomp : nSubfree n = true ∧ fSubfree rest = true := by
          simpa only [fSubfree, Bool.and_eq_true] using h
        have hn : nSubfree n = true := hcomp.1
        have hfr : fSubfree rest = true := hcomp.2
        obtain ⟨nb, ni⟩ := nFaithful n hn
        obtain ⟨fb, fi⟩ := fFaithful rest hfr
        rw [fBound_node_nb hna]
        -- reduce each entry through its owning split
        have hsplit : ∀ e : Entries (nsingle (.prod (.node n rest))),
            IsHT n (prodNode rest) e.1 (someSplit n (prodNode rest) e.1) :=
          fun e => someSplit_isHT _ _ _ (prodNode_node_split_exists hna e)
        have hval : ∀ e : Entries (nsingle (.prod (.node n rest))),
            fRank (.node n rest) e
              = fBound rest * nRank n ⟨_, (hsplit e).2.1⟩ + fRank rest ⟨_, (hsplit e).2.2⟩ :=
          fun e => fRank_node_nb hna e (hsplit e).2.1 (hsplit e).2.2
        constructor
        · intro e
          rw [hval e]
          exact mixmul_lt (fb _) (nb _)
        · intro x y hxy
          rw [hval x, hval y] at hxy
          have hWpos : (0 : Ordinal) < fBound rest :=
            zero_le.trans_lt (fb ⟨_, (hsplit x).2.2⟩)
          obtain ⟨hqe, hre⟩ := mixmul_inj hWpos.ne' (fb _) (fb _) hxy
          have hhead : (someSplit n (prodNode rest) x.1).1 = (someSplit n (prodNode rest) y.1).1 :=
            congrArg Subtype.val (ni hqe)
          have htail : (someSplit n (prodNode rest) x.1).2 = (someSplit n (prodNode rest) y.1).2 :=
            congrArg Subtype.val (fi hre)
          apply Subtype.ext
          rw [(hsplit x).1, (hsplit y).1, hhead, htail]

end

/- ---- The payoff: the recursive within-body order is a well order. ---- -/

/-- `entryRank` is injective on the subtraction-free skeleton. -/
theorem entryRank_injective (n : Node) (h : nSubfree n = true) :
    Function.Injective (entryRank n) :=
  (nFaithful n h).2

/-- The bound invariant: every entry ranks strictly below `entryBound`. -/
theorem entryRank_lt_entryBound (n : Node) (h : nSubfree n = true) (e : Entries n) :
    entryRank n e < entryBound n :=
  (nFaithful n h).1 e

/-- The recursive within-body order is a well order on the subtraction-free
skeleton -- the goal of the increment. -/
theorem entryRecLt_isWellOrder (n : Node) (h : nSubfree n = true) :
    IsWellOrder (Entries n) (entryRecLt n) :=
  RecOrder.isWellOrder_of_injective (entryRank n) (entryRank_injective n h)

/- ---- Leaf agreement: on a leaf member the recursion bottoms out on the       -/
/- shortlex order it replaces, so the new order restricts to the old on leaves. -/
/- This is the compatibility hinge -- every constructor case ultimately reduces  -/
/- through a leaf, so the recursion is a conservative extension of `entrySpellLt` -/
/- rather than a different order on the base cases.                              -/

/-- On a leaf member -- a single non-binding member whose rank is exactly the
shortlex `typein` -- the body-recursive rank is that same `typein`. The union
spine reduces `nsingle m = m :: nil` to its head, and the head is a bare leaf. -/
theorem entryRank_leaf (m : Member) (hb : bindsb (nsingle m) = false)
    (hm : ∀ e, mRank m e = Ordinal.typein (entrySpellLt (nsingle m)) e) :
    entryRank (nsingle m) = Ordinal.typein (entrySpellLt (nsingle m)) := by
  funext e
  show nRank (Node.cons m Node.nil) e = _
  rw [nRank_cons_first hb e e.2]
  exact hm _

/-- Leaf agreement: on a leaf member the recursive within-body order `entryRecLt`
is definitionally the shortlex order `entrySpellLt` it extends. -/
theorem entryRecLt_leaf (m : Member) (hb : bindsb (nsingle m) = false)
    (hm : ∀ e, mRank m e = Ordinal.typein (entrySpellLt (nsingle m)) e) :
    entryRecLt (nsingle m) = entrySpellLt (nsingle m) := by
  show RecOrder.rankLt (entryRank (nsingle m)) = _
  rw [entryRank_leaf m hb hm]
  exact RecOrder.rankLt_typein_eq

theorem entryRecLt_face (t : Spelling) :
    entryRecLt (nsingle (.face t)) = entrySpellLt (nsingle (.face t)) :=
  entryRecLt_leaf (.face t) (by simp [nsingle, bindsb, freeAmpb])
    (fun e => by simp only [mRank])

theorem entryRecLt_range (lo hi : Code) :
    entryRecLt (nsingle (.range lo hi)) = entrySpellLt (nsingle (.range lo hi)) :=
  entryRecLt_leaf (.range lo hi) (by simp [nsingle, bindsb, freeAmpb])
    (fun e => by simp only [mRank])

theorem entryRecLt_final (lo : Spelling) :
    entryRecLt (nsingle (.final lo)) = entrySpellLt (nsingle (.final lo)) :=
  entryRecLt_leaf (.final lo) (by simp [nsingle, bindsb, freeAmpb])
    (fun e => by simp only [mRank])

/- ================================================================ -/
/- STEP 4: the closure within-stage order -- the stage-structure     -/
/- backbone. A closure enumerates its entries stage-major (its        -/
/- `firstStage`), and within a single stage `k+1` an entry is a       -/
/- body-spelling `walk n (stage n k) False s` whose `&`-leaves are    -/
/- filled from strictly earlier stages -- a body-recursive shape (the -/
/- body half, a later slice). This section is the stage half: given   -/
/- ANY within-stage rank that is bounded by and injective within each -/
/- stage, the stage-major assembly (ladder offset plus within-stage   -/
/- rank) is an injective rank, hence a well order. The offset is a    -/
/- FINITE sum -- `firstStage` is a `ℕ` -- so it is iterated ordinal   -/
/- addition: the union-block disjoint-interval argument run along the -/
/- stage ladder rather than the member spine. It is to the ladder     -/
/- what `mixmul_lt`/`mixmul_inj` are to the product.                  -/
/- ================================================================ -/

namespace RecOrder

/-- The ladder offset: the ordinal width of every stage strictly below `k`,
a finite sum since `k : ℕ`. Stage `k`'s rank block starts here. -/
noncomputable def stageOffset (W : ℕ → Ordinal) : ℕ → Ordinal
  | 0 => 0
  | k + 1 => stageOffset W k + W k

theorem stageOffset_le_succ (W : ℕ → Ordinal) (k : ℕ) :
    stageOffset W k ≤ stageOffset W (k + 1) := by
  rw [stageOffset]; exact le_self_add

theorem stageOffset_mono (W : ℕ → Ordinal) {k k' : ℕ} (h : k ≤ k') :
    stageOffset W k ≤ stageOffset W k' := by
  induction h with
  | refl => exact le_refl _
  | step _ ih => exact ih.trans (stageOffset_le_succ W _)

/-- The stage-major rank: the ladder offset of the entry's stage plus its
within-stage rank. -/
noncomputable def stageRank {β : Type*} (st : β → ℕ) (W : ℕ → Ordinal)
    (w : β → Ordinal) (e : β) : Ordinal :=
  stageOffset W (st e) + w e

/-- A strictly earlier stage's whole block sits below the next ladder offset,
so its every rank is strictly below every rank of a later stage. This is the
cross-stage disjointness that makes the assembly injective. -/
theorem stageRank_lt_of_stage_lt {β : Type*} (st : β → ℕ) (W : ℕ → Ordinal)
    (w : β → Ordinal) (hbound : ∀ e, w e < W (st e)) {x y : β} (h : st x < st y) :
    stageRank st W w x < stageRank st W w y := by
  have h1 : stageRank st W w x < stageOffset W (st x + 1) := by
    rw [stageRank, stageOffset]; exact (add_lt_add_iff_left _).2 (hbound x)
  have h2 : stageOffset W (st x + 1) ≤ stageOffset W (st y) := stageOffset_mono W h
  have h3 : stageOffset W (st y) ≤ stageRank st W w y := by
    rw [stageRank]; exact le_self_add
  exact h1.trans_le (h2.trans h3)

/-- The stage-major rank is injective given a within-stage rank that stays
below its stage's bound and is injective within each stage. Cross-stage
distinctness is the block disjointness above; within a stage the shared offset
cancels on the left and the per-stage injectivity finishes. -/
theorem stageRank_injective {β : Type*} (st : β → ℕ) (W : ℕ → Ordinal)
    (w : β → Ordinal) (hbound : ∀ e, w e < W (st e))
    (hinj : ∀ x y, st x = st y → w x = w y → x = y) :
    Function.Injective (stageRank st W w) := by
  intro x y hxy
  rcases lt_trichotomy (st x) (st y) with hlt | heq | hgt
  · exact absurd hxy (ne_of_lt (stageRank_lt_of_stage_lt st W w hbound hlt))
  · simp only [stageRank, heq] at hxy
    exact hinj x y heq ((add_left_cancel_iff).1 hxy)
  · exact absurd hxy.symm (ne_of_lt (stageRank_lt_of_stage_lt st W w hbound hgt))

/-- The payoff of the stage half: the stage-major assembly is a well order --
its rank is injective, so `rankLt` inherits the ordinals' well-order. The body
half (a bounded, per-stage-injective within-stage rank on real closures) plugs
into `hbound`/`hinj` in the follow-up slice. -/
theorem stageRank_isWellOrder {β : Type*} (st : β → ℕ) (W : ℕ → Ordinal)
    (w : β → Ordinal) (hbound : ∀ e, w e < W (st e))
    (hinj : ∀ x y, st x = st y → w x = w y → x = y) :
    IsWellOrder β (rankLt (stageRank st W w)) :=
  isWellOrder_of_injective _ (stageRank_injective st W w hbound hinj)

end RecOrder

/- ================================================================ -/
/- STEP 4b: the within-stage body-membership inversions -- the       -/
/- general-amp generalization of the reinterpretation block above.   -/
/- Within a closure's stage `k+1` a body-spelling lives in            -/
/- `walk n (stage n k) False`, not in `denotes n = walk n ∅ False`,   -/
/- so the union / fold / product reinterpretations the within-stage   -/
/- rank recurses through are restated over an arbitrary amp-set       -/
/- `amp` (the earlier stage). Their proofs are the amp-general core    -/
/- the `denotes_*` versions already specialize -- `walk_adds`,         -/
/- `walk_single_*`, `fsplit_fnode` are all amp-parametric -- so the    -/
/- only change is dropping the `bindsb` guards `denotes` strips        -/
/- through `ndenote_nonbinder`. The `.amp` leaf, vacuous at the floor  -/
/- (`walk (nsingle .amp) ∅ False = ∅`), here wears the earlier stage:  -/
/- it is the leaf the within-stage rank defers to a supplied           -/
/- earlier-stage rank (slice 4c ties that knot).                       -/
/- ================================================================ -/

/-- The `.amp` leaf's within-stage membership: over amp-set `amp` it wears
exactly `amp` (the earlier stage). Vacuous at the floor where `amp = ∅`; this
is the leaf the within-stage rank ranks by the supplied earlier-stage rank. -/
theorem walk_single_amp_false (amp : Spelling → Prop) (s : Spelling) :
    walk (nsingle .amp) amp False s ↔ amp s := by
  rw [walk_single_amp, false_or]

/-- Union first-owner inversion over an arbitrary amp-set: a union walks
exactly the two bodies' amp-memberships. The `denotes` version
(`denotes_napp_iff`) is the `amp = ∅` case; over a general amp no `bindsb`
guard is needed, since `walk` never consults it on the spine -- only the
subtraction-free hypothesis on the second body survives. -/
theorem walk_napp_iff (n1 n2 : Node) (amp : Spelling → Prop)
    (hsf2 : subfreeb n2 = true) (s : Spelling) :
    walk (napp n1 n2) amp False s ↔ walk n1 amp False s ∨ walk n2 amp False s := by
  rw [walk_app, walk_adds n2 amp (walk n1 amp False s) s hsf2,
    walk_adds n2 amp False s hsf2]
  tauto

/-- Fold-of-a-non-binder inversion over an arbitrary amp-set: the amp-general
core of `denotes_fold_nonbinder`. A fold whose inner universe does not bind
wears inner's amp-membership, plus the empty spelling when inner is empty. -/
theorem walk_fold_nonbinder (inner : Node) (amp : Spelling → Prop) (s : Spelling)
    (h : bindsb inner = false) :
    walk (nsingle (.fold inner)) amp False s
      ↔ walk inner amp False s ∨ (s = [] ∧ ∀ t, ¬ walk inner amp False t) := by
  simp only [walk_single_fold, false_or, spells_fold, h, Bool.false_eq_true, if_false]

/-- A product's within-stage membership is its factor split over the same
amp-set -- `walk_single_prod` with the seed `False` collapsed. -/
theorem walk_prodNode_fsplit (fs : Factors) (amp : Spelling → Prop) (s : Spelling) :
    walk (prodNode fs) amp False s ↔ fsplit fs amp s := by
  show walk (nsingle (.prod fs)) amp False s ↔ _
  rw [walk_single_prod, false_or]

/-- Head/tail split of a product with a non-binder head over an arbitrary
amp-set: the amp-general `prodNode_node_split`. The head `n` is a non-binder
(a literal `&` in the head would rebind, routing to the closure fallback), so
its `ndenote` collapses to `walk n amp False`. -/
theorem walk_prodNode_node_split (n : Node) (rest : Factors) (amp : Spelling → Prop)
    (hbn : bindsb n = false) (s : Spelling) :
    walk (prodNode (.node n rest)) amp False s
      ↔ ∃ p q, s = p ++ q ∧ walk n amp False p ∧ walk (prodNode rest) amp False q := by
  rw [walk_prodNode_fsplit, fsplit_fnode]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    exact ⟨p, q, rfl, (ndenote_nonbinder n amp p hbn).mp hp,
      (walk_prodNode_fsplit rest amp q).mpr hq⟩
  · rintro ⟨p, q, rfl, hp, hq⟩
    exact ⟨p, q, rfl, (ndenote_nonbinder n amp p hbn).mpr hp,
      (walk_prodNode_fsplit rest amp q).mp hq⟩

/- ================================================================ -/
/- STEP 4b-ii-a: the within-stage body recursion -- DEFINITIONS.     -/
/- A parallel copy of the step-2 recursion (`mRank`/`nRank`/`fRank`)  -/
/- over `walk n amp False` membership instead of `denotes n`,         -/
/- parameterized by a supplied earlier-stage rank `(ampRank,          -/
/- ampBound)`. The `.amp` leaf ranks by `ampRank` (via 4b-i's          -/
/- `walk_single_amp_false`); an amp-consuming factor (`.amp rest`, or  -/
/- a `.node n rest` head that meets `amp`) recurses rather than         -/
/- falling back; a nested closure -- a fold-of-binder or a binder head -/
/- -- is amp-independent and keeps the `typein (entryLt ·)` fallback.  -/
/- Faithfulness (the `hbound`/`hinj` input to 4a) is the next slice.   -/
/- ================================================================ -/

/- ---- Carrier coercions: an amp-independent leaf/closure entry is a `denotes` entry. ---- -/

theorem walk_face_denotes (t : Spelling) (amp : Spelling → Prop) (s : Spelling)
    (h : walk (nsingle (.face t)) amp False s) : denotes (nsingle (.face t)) s := by
  rw [walk_single_face] at h
  show ndenote (nsingle (.face t)) (fun _ => False) s
  exact (ndenote_face t _ s).mpr (h.resolve_left not_false)

theorem walk_range_denotes (lo hi : Code) (amp : Spelling → Prop) (s : Spelling)
    (h : walk (nsingle (.range lo hi)) amp False s) : denotes (nsingle (.range lo hi)) s := by
  rw [walk_single_range] at h
  show ndenote (nsingle (.range lo hi)) (fun _ => False) s
  rw [ndenote_nonbinder _ _ _ (by simp [nsingle, bindsb, freeAmpb]), walk_single_range]
  exact h

theorem walk_final_denotes (lo : Spelling) (amp : Spelling → Prop) (s : Spelling)
    (h : walk (nsingle (.final lo)) amp False s) : denotes (nsingle (.final lo)) s := by
  rw [walk_single_final] at h
  show ndenote (nsingle (.final lo)) (fun _ => False) s
  rw [ndenote_nonbinder _ _ _ (by simp [nsingle, bindsb, freeAmpb]), walk_single_final]
  exact h

theorem walk_prodnil_denotes (amp : Spelling → Prop) (s : Spelling)
    (h : walk (nsingle (.prod .nil)) amp False s) : denotes (nsingle (.prod .nil)) s := by
  have h2 : fsplit .nil amp s := (walk_prodNode_fsplit .nil amp s).mp h
  rw [fsplit_fnil] at h2
  show ndenote (nsingle (.prod .nil)) (fun _ => False) s
  rw [ndenote_nonbinder _ _ _ (by simp [nsingle, bindsb, freeAmpb, hasAmpb])]
  exact (walk_prodNode_fsplit .nil (fun _ => False) s).mpr (by rw [fsplit_fnil]; exact h2)

theorem walk_fold_binder_denotes (inner : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb inner = true) (h : walk (nsingle (.fold inner)) amp False s) :
    denotes (nsingle (.fold inner)) s := by
  rw [walk_single_fold, false_or, spells_fold, if_pos hb] at h
  show ndenote (nsingle (.fold inner)) (fun _ => False) s
  rw [ndenote_nonbinder _ _ _ (by simp [nsingle, bindsb, freeAmpb]),
    walk_single_fold, false_or, spells_fold, if_pos hb]
  exact h

theorem ndenote_binder_denotes (n : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb n = true) (h : ndenote n amp s) : denotes n s := by
  rw [ndenote_binder n amp s hb] at h
  rw [denotes, ndenote_binder n _ s hb]
  exact h

/- ---- The generic least head/tail split over two predicates. ---- -/

open Classical in
/-- The least split of `s` into `p ++ q` with `headP p` and `tailP q`, junk
`([], [])` when none. Generalizes `someSplit` off the `denotes`-specific `IsHT`
to any pair of piece predicates -- the within-stage product recursion splits on
`walk`/`amp` predicates, not `denotes`. -/
noncomputable def someSplitP (headP tailP : Spelling → Prop) (s : Spelling) :
    Spelling × Spelling :=
  if h : ∃ pq : Spelling × Spelling, s = pq.1 ++ pq.2 ∧ headP pq.1 ∧ tailP pq.2
  then (IsWellFounded.wf (r := splitLt)).min _ h
  else ([], [])

/- ---- The within-stage recursion. ---- -/

section WithinStage

variable (amp : Spelling → Prop) (ampRank : {s : Spelling // amp s} → Ordinal)
  (ampBound : Ordinal)

open Classical in
mutual

/-- Within-stage rank of a one-member node's entry. -/
noncomputable def wmRank :
    (m : Member) → {s : Spelling // walk (nsingle m) amp False s} → Ordinal
  | .face t, e => typein (entrySpellLt (nsingle (.face t))) ⟨e.1, walk_face_denotes t amp e.1 e.2⟩
  | .range lo hi, e =>
      typein (entrySpellLt (nsingle (.range lo hi))) ⟨e.1, walk_range_denotes lo hi amp e.1 e.2⟩
  | .final lo, e =>
      typein (entrySpellLt (nsingle (.final lo))) ⟨e.1, walk_final_denotes lo amp e.1 e.2⟩
  | .amp, e => ampRank ⟨e.1, (walk_single_amp_false amp e.1).mp e.2⟩
  | .sub _, _ => 0
  | .fold inner, e =>
      if hb : bindsb inner = true then
        typein (entryLt (nsingle (.fold inner)))
          ⟨e.1, walk_fold_binder_denotes inner amp e.1 hb e.2⟩
      else if h : walk inner amp False e.1 then wnRank inner ⟨e.1, h⟩ else 0
  | .prod fs, e => wfRank fs ⟨e.1, e.2⟩

/-- Within-stage rank of a node's entry (union spine): first-owner, no closure
fallback -- a bare `&` member consults `amp` and is ranked recursively. -/
noncomputable def wnRank : (n : Node) → {s : Spelling // walk n amp False s} → Ordinal
  | .nil, _ => 0
  | .cons m rest, e =>
      if h : walk (nsingle m) amp False e.1 then wmRank m ⟨e.1, h⟩
      else if h2 : walk rest amp False e.1 then wmBound m + wnRank rest ⟨e.1, h2⟩ else 0

/-- Within-stage rank of a product's entry, positional (mixed radix) over the
factor pieces its least split carves. -/
noncomputable def wfRank :
    (fs : Factors) → {s : Spelling // walk (nsingle (.prod fs)) amp False s} → Ordinal
  | .nil, e =>
      typein (entrySpellLt (nsingle (.prod .nil))) ⟨e.1, walk_prodnil_denotes amp e.1 e.2⟩
  | .amp rest, e =>
      wfBound rest * (if h : amp (someSplitP amp (fun q => fsplit rest amp q) e.1).1
          then ampRank ⟨_, h⟩ else 0)
        + (if h : walk (nsingle (.prod rest)) amp False
              (someSplitP amp (fun q => fsplit rest amp q) e.1).2
            then wfRank rest ⟨_, h⟩ else 0)
  | .node n rest, e =>
      wfBound rest * (if bindsb n then
            (if h : denotes n (someSplitP (fun p => ndenote n amp p)
                (fun q => fsplit rest amp q) e.1).1
              then typein (entryLt n) ⟨_, h⟩ else 0)
          else
            (if h : walk n amp False (someSplitP (fun p => ndenote n amp p)
                (fun q => fsplit rest amp q) e.1).1
              then wnRank n ⟨_, h⟩ else 0))
        + (if h : walk (nsingle (.prod rest)) amp False
              (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).2
            then wfRank rest ⟨_, h⟩ else 0)

/-- Within-stage bound contributed by a one-member node. -/
noncomputable def wmBound : Member → Ordinal
  | .face t => entriesType (nsingle (.face t))
  | .range lo hi => entriesType (nsingle (.range lo hi))
  | .final lo => entriesType (nsingle (.final lo))
  | .amp => ampBound
  | .sub _ => 0
  | .fold inner =>
      if bindsb inner then closureBound (nsingle (.fold inner)) else wnBound inner + 1
  | .prod fs => wfBound fs

/-- Within-stage bound contributed by a node: sum of members' block widths (no
closure fallback -- a bare `&` block has width `ampBound`, not its own order type). -/
noncomputable def wnBound : Node → Ordinal
  | .nil => 0
  | .cons m rest => wmBound m + wnBound rest

/-- Within-stage bound contributed by a factor list: the mixed-radix width, tail
base times head count, with an amp head counting `ampBound` and a binder head its
own closure order type. -/
noncomputable def wfBound : Factors → Ordinal
  | .nil => entriesType (nsingle (.prod .nil))
  | .amp rest => wfBound rest * ampBound
  | .node n rest => wfBound rest * (if bindsb n then closureBound n else wnBound n)

end

/- ---- One-step unfolding lemmas for the recursive branches. ---- -/

theorem wnBound_cons (m : Member) (rest : Node) :
    wnBound amp ampRank ampBound (.cons m rest)
      = wmBound amp ampRank ampBound m + wnBound amp ampRank ampBound rest := by
  simp only [wnBound]

theorem wnRank_cons_first (m : Member) (rest : Node)
    (e : {s : Spelling // walk (.cons m rest) amp False s})
    (hd : walk (nsingle m) amp False e.1) :
    wnRank amp ampRank ampBound (.cons m rest) e = wmRank amp ampRank ampBound m ⟨e.1, hd⟩ := by
  simp only [wnRank, dif_pos hd]

theorem wnRank_cons_rest (m : Member) (rest : Node)
    (e : {s : Spelling // walk (.cons m rest) amp False s})
    (h1 : ¬ walk (nsingle m) amp False e.1) (hd : walk rest amp False e.1) :
    wnRank amp ampRank ampBound (.cons m rest) e
      = wmBound amp ampRank ampBound m + wnRank amp ampRank ampBound rest ⟨e.1, hd⟩ := by
  simp only [wnRank, dif_neg h1, dif_pos hd]

theorem wfBound_amp (rest : Factors) :
    wfBound amp ampRank ampBound (.amp rest) = wfBound amp ampRank ampBound rest * ampBound := by
  simp only [wfBound]

theorem wfBound_node (n : Node) (rest : Factors) :
    wfBound amp ampRank ampBound (.node n rest)
      = wfBound amp ampRank ampBound rest
        * (if bindsb n then closureBound n else wnBound amp ampRank ampBound n) := by
  simp only [wfBound]

end WithinStage

/- ================================================================ -/
/- STEP 4b-ii-b: within-stage faithfulness -- the composition proof   -/
/- of step 2 with `amp` threaded through. Given a faithful supplied   -/
/- amp-rank (`Faithful ampRank ampBound`), the within-stage recursion  -/
/- is faithful (injective + bounded) on the subtraction-free           -/
/- skeleton: the `.amp` leaf is discharged by the supplied amp-rank,    -/
/- the amp-factor / binder-head product cases by the mixed-radix        -/
/- arithmetic (`mixmul_lt`/`mixmul_inj`), and every union/fold/product  -/
/- routing by the 4b-i `walk_*` inversions. `wnFaithful` is the per-     -/
/- stage `hbound`/`hinj` input to 4a's `stageRank_isWellOrder`; slice   -/
/- 4c feeds it with the real body at each stage. -/
/- ================================================================ -/

/- Helper: the least split's spec, generic over the two piece predicates. -/
theorem someSplitP_spec (headP tailP : Spelling → Prop) (s : Spelling)
    (h : ∃ pq : Spelling × Spelling, s = pq.1 ++ pq.2 ∧ headP pq.1 ∧ tailP pq.2) :
    s = (someSplitP headP tailP s).1 ++ (someSplitP headP tailP s).2
      ∧ headP (someSplitP headP tailP s).1 ∧ tailP (someSplitP headP tailP s).2 := by
  rw [someSplitP, dif_pos h]
  exact WellFounded.min_mem _ _ h

/-- Two entries of a `walk`-carrier subtype are equal once their images under a
value-preserving coercion into another subtype agree -- the coercion only ever
changes the membership proof, never the spelling. -/
theorem wentry_ext {P Q : Spelling → Prop} {x y : Subtype P}
    {hx : Q x.1} {hy : Q y.1} (h : (⟨x.1, hx⟩ : Subtype Q) = ⟨y.1, hy⟩) : x = y := by
  have hv := congrArg Subtype.val h
  exact Subtype.ext hv

section WithinStageFaithful

variable (amp : Spelling → Prop) (ampRank : {s : Spelling // amp s} → Ordinal)
  (ampBound : Ordinal) (hamp : Faithful ampRank ampBound)

/- Reduced unfolding of the product recursion when its owning split is genuine. -/
theorem wfRank_amp_pos (rest : Factors)
    (e : {s : Spelling // walk (nsingle (.prod (.amp rest))) amp False s})
    (hp : amp (someSplitP amp (fun q => fsplit rest amp q) e.1).1)
    (hq : walk (nsingle (.prod rest)) amp False
        (someSplitP amp (fun q => fsplit rest amp q) e.1).2) :
    wfRank amp ampRank ampBound (.amp rest) e
      = wfBound amp ampRank ampBound rest * ampRank ⟨_, hp⟩
        + wfRank amp ampRank ampBound rest ⟨_, hq⟩ := by
  simp only [wfRank, dif_pos hp, dif_pos hq]

theorem wfRank_node_binder_pos (n : Node) (rest : Factors) (hb : bindsb n = true)
    (e : {s : Spelling // walk (nsingle (.prod (.node n rest))) amp False s})
    (hp : denotes n (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).1)
    (hq : walk (nsingle (.prod rest)) amp False
        (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).2) :
    wfRank amp ampRank ampBound (.node n rest) e
      = wfBound amp ampRank ampBound rest * typein (entryLt n) ⟨_, hp⟩
        + wfRank amp ampRank ampBound rest ⟨_, hq⟩ := by
  simp only [wfRank, if_pos hb, dif_pos hp, dif_pos hq]

theorem wfRank_node_nonbinder_pos (n : Node) (rest : Factors) (hb : bindsb n = false)
    (e : {s : Spelling // walk (nsingle (.prod (.node n rest))) amp False s})
    (hp : walk n amp False (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).1)
    (hq : walk (nsingle (.prod rest)) amp False
        (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).2) :
    wfRank amp ampRank ampBound (.node n rest) e
      = wfBound amp ampRank ampBound rest * wnRank amp ampRank ampBound n ⟨_, hp⟩
        + wfRank amp ampRank ampBound rest ⟨_, hq⟩ := by
  simp only [wfRank, hb, Bool.false_eq_true, if_false, dif_pos hp, dif_pos hq]

/- ---- The mutual within-stage faithfulness theorem. ---- -/

include hamp

set_option linter.unusedSectionVars false in
mutual

theorem wmFaithful : ∀ (m : Member), mSubfree m = true →
    Faithful (wmRank amp ampRank ampBound m) (wmBound amp ampRank ampBound m)
  | .face t, _ => by
      refine ⟨fun e => ?_, fun x y hxy => ?_⟩
      · simp only [wmRank, wmBound, entriesType]; exact typein_lt_type _ _
      · simp only [wmRank] at hxy
        have hinj := typein_injective _ hxy
        exact wentry_ext hinj
  | .range lo hi, _ => by
      refine ⟨fun e => ?_, fun x y hxy => ?_⟩
      · simp only [wmRank, wmBound, entriesType]; exact typein_lt_type _ _
      · simp only [wmRank] at hxy
        have hinj := typein_injective _ hxy
        exact wentry_ext hinj
  | .final lo, _ => by
      refine ⟨fun e => ?_, fun x y hxy => ?_⟩
      · simp only [wmRank, wmBound, entriesType]; exact typein_lt_type _ _
      · simp only [wmRank] at hxy
        have hinj := typein_injective _ hxy
        exact wentry_ext hinj
  | .amp, _ => by
      refine ⟨fun e => ?_, fun x y hxy => ?_⟩
      · simp only [wmRank, wmBound]; exact hamp.1 _
      · simp only [wmRank] at hxy
        have hinj := hamp.2 hxy
        exact wentry_ext hinj
  | .sub _, h => absurd h (by simp [mSubfree])
  | .fold inner, h => by
      by_cases hb : bindsb inner = true
      · refine ⟨fun e => ?_, fun x y hxy => ?_⟩
        · simp only [wmRank, wmBound, dif_pos hb, if_pos hb, closureBound]
          exact typein_lt_type _ _
        · simp only [wmRank, dif_pos hb] at hxy
          have hinj := typein_injective _ hxy
          exact wentry_ext hinj
      · rw [Bool.not_eq_true] at hb
        have hbf : ¬ (bindsb inner = true) := by simp [hb]
        have hin : nSubfree inner = true := by simpa only [mSubfree] using h
        obtain ⟨ib, ii⟩ := wnFaithful inner hin
        refine ⟨fun e => ?_, fun x y hxy => ?_⟩
        · simp only [wmRank, wmBound, dif_neg hbf, if_neg hbf]
          by_cases hd : walk inner amp False e.1
          · rw [dif_pos hd]; exact (ib ⟨e.1, hd⟩).trans_le le_self_add
          · rw [dif_neg hd]; exact zero_lt_one.trans_le le_add_self
        · simp only [wmRank, dif_neg hbf] at hxy
          have hxc := (walk_fold_nonbinder inner amp x.1 hb).mp x.2
          have hyc := (walk_fold_nonbinder inner amp y.1 hb).mp y.2
          by_cases hdx : walk inner amp False x.1 <;> by_cases hdy : walk inner amp False y.1
          · rw [dif_pos hdx, dif_pos hdy] at hxy
            have hinj := ii hxy
            exact wentry_ext hinj
          · exact absurd hdx ((hyc.resolve_left hdy).2 x.1)
          · exact absurd hdy ((hxc.resolve_left hdx).2 y.1)
          · exact Subtype.ext (((hxc.resolve_left hdx).1).trans ((hyc.resolve_left hdy).1).symm)
  | .prod fs, h => by
      have hfs : fSubfree fs = true := by simpa only [mSubfree] using h
      obtain ⟨fb, fi⟩ := wfFaithful fs hfs
      refine ⟨fun e => ?_, fun x y hxy => ?_⟩
      · simp only [wmRank, wmBound]; exact fb _
      · simp only [wmRank] at hxy; exact fi hxy

theorem wnFaithful : ∀ (n : Node), nSubfree n = true →
    Faithful (wnRank amp ampRank ampBound n) (wnBound amp ampRank ampBound n)
  | .nil, _ =>
      ⟨fun e => absurd e.2 (by rw [walk_nil]; exact not_false),
       fun x _ _ => absurd x.2 (by rw [walk_nil]; exact not_false)⟩
  | .cons m rest, h => by
      have hcomp : mSubfree m = true ∧ nSubfree rest = true := by
        simpa only [nSubfree, Bool.and_eq_true] using h
      have hm := hcomp.1
      have hr := hcomp.2
      have hsf : subfreeb rest = true := nSubfree_subfreeb rest hr
      obtain ⟨mb, mi⟩ := wmFaithful m hm
      obtain ⟨nb, ni⟩ := wnFaithful rest hr
      have hcase : ∀ e : {s : Spelling // walk (.cons m rest) amp False s},
          (∃ hd : walk (nsingle m) amp False e.1,
              wnRank amp ampRank ampBound (.cons m rest) e = wmRank amp ampRank ampBound m ⟨e.1, hd⟩) ∨
          (∃ hd : walk rest amp False e.1, ¬ walk (nsingle m) amp False e.1 ∧
              wnRank amp ampRank ampBound (.cons m rest) e
                = wmBound amp ampRank ampBound m + wnRank amp ampRank ampBound rest ⟨e.1, hd⟩) := by
        intro e
        rcases (walk_napp_iff (nsingle m) rest amp hsf e.1).mp e.2 with hA | hB
        · exact Or.inl ⟨hA, wnRank_cons_first amp ampRank ampBound m rest e hA⟩
        · by_cases hA : walk (nsingle m) amp False e.1
          · exact Or.inl ⟨hA, wnRank_cons_first amp ampRank ampBound m rest e hA⟩
          · exact Or.inr ⟨hB, hA, wnRank_cons_rest amp ampRank ampBound m rest e hA hB⟩
      rw [wnBound_cons]
      constructor
      · intro e
        rcases hcase e with ⟨hd, he⟩ | ⟨hd, _, he⟩
        · rw [he]; exact (mb _).trans_le le_self_add
        · rw [he]; exact (add_lt_add_iff_left _).2 (nb _)
      · intro x y hxy
        rcases hcase x with ⟨hdx, hex⟩ | ⟨hdx, hnx, hex⟩ <;>
          rcases hcase y with ⟨hdy, hey⟩ | ⟨hdy, hny, hey⟩
        · rw [hex, hey] at hxy
          have hinj := mi hxy
          exact wentry_ext hinj
        · rw [hex, hey] at hxy
          exact absurd hxy (ne_of_lt ((mb _).trans_le le_self_add))
        · rw [hex, hey] at hxy
          exact absurd hxy.symm (ne_of_lt ((mb _).trans_le le_self_add))
        · rw [hex, hey] at hxy
          have hinj := ni ((add_left_cancel_iff).1 hxy)
          exact wentry_ext hinj

theorem wfFaithful : ∀ (fs : Factors), fSubfree fs = true →
    Faithful (wfRank amp ampRank ampBound fs) (wfBound amp ampRank ampBound fs)
  | .nil, _ => by
      refine ⟨fun e => ?_, fun x y hxy => ?_⟩
      · simp only [wfRank, wfBound, entriesType]; exact typein_lt_type _ _
      · simp only [wfRank] at hxy
        have hinj := typein_injective _ hxy
        exact wentry_ext hinj
  | .amp rest, h => by
      have hfr : fSubfree rest = true := by simpa only [fSubfree] using h
      obtain ⟨fb, fi⟩ := wfFaithful rest hfr
      rw [wfBound_amp]
      have hspec : ∀ e : {s : Spelling // walk (nsingle (.prod (.amp rest))) amp False s},
          e.1 = (someSplitP amp (fun q => fsplit rest amp q) e.1).1
              ++ (someSplitP amp (fun q => fsplit rest amp q) e.1).2
            ∧ amp (someSplitP amp (fun q => fsplit rest amp q) e.1).1
            ∧ fsplit rest amp (someSplitP amp (fun q => fsplit rest amp q) e.1).2 := by
        intro e
        apply someSplitP_spec
        have hf := (walk_prodNode_fsplit (.amp rest) amp e.1).mp e.2
        rw [fsplit_famp] at hf
        obtain ⟨p, q, hpq, hp, hq⟩ := hf
        exact ⟨(p, q), hpq, hp, hq⟩
      have hval : ∀ e : {s : Spelling // walk (nsingle (.prod (.amp rest))) amp False s},
          wfRank amp ampRank ampBound (.amp rest) e
            = wfBound amp ampRank ampBound rest * ampRank ⟨_, (hspec e).2.1⟩
              + wfRank amp ampRank ampBound rest
                  ⟨_, (walk_prodNode_fsplit rest amp _).mpr (hspec e).2.2⟩ :=
        fun e => wfRank_amp_pos amp ampRank ampBound rest e (hspec e).2.1
          ((walk_prodNode_fsplit rest amp _).mpr (hspec e).2.2)
      constructor
      · intro e; rw [hval e]; exact mixmul_lt (fb _) (hamp.1 _)
      · intro x y hxy
        rw [hval x, hval y] at hxy
        have hWpos : (0 : Ordinal) < wfBound amp ampRank ampBound rest :=
            zero_le.trans_lt (fb ⟨_, (walk_prodNode_fsplit rest amp _).mpr (hspec x).2.2⟩)
        obtain ⟨hqe, hre⟩ := mixmul_inj hWpos.ne' (fb _) (fb _) hxy
        have hhead : (someSplitP amp (fun q => fsplit rest amp q) x.1).1
            = (someSplitP amp (fun q => fsplit rest amp q) y.1).1 :=
          congrArg Subtype.val (hamp.2 hqe)
        have htail : (someSplitP amp (fun q => fsplit rest amp q) x.1).2
            = (someSplitP amp (fun q => fsplit rest amp q) y.1).2 :=
          congrArg Subtype.val (fi hre)
        apply Subtype.ext
        rw [(hspec x).1, (hspec y).1, hhead, htail]
  | .node n rest, h => by
      have hcomp : nSubfree n = true ∧ fSubfree rest = true := by
        simpa only [fSubfree, Bool.and_eq_true] using h
      have hn := hcomp.1
      have hfr := hcomp.2
      obtain ⟨fb, fi⟩ := wfFaithful rest hfr
      rw [wfBound_node]
      have hspec : ∀ e : {s : Spelling // walk (nsingle (.prod (.node n rest))) amp False s},
          e.1 = (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).1
              ++ (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).2
            ∧ ndenote n amp (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).1
            ∧ fsplit rest amp (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) e.1).2 := by
        intro e
        apply someSplitP_spec
        have hf := (walk_prodNode_fsplit (.node n rest) amp e.1).mp e.2
        rw [fsplit_fnode] at hf
        obtain ⟨p, q, hpq, hp, hq⟩ := hf
        exact ⟨(p, q), hpq, hp, hq⟩
      by_cases hb : bindsb n = true
      · simp only [if_pos hb]
        have hval : ∀ e : {s : Spelling // walk (nsingle (.prod (.node n rest))) amp False s},
            wfRank amp ampRank ampBound (.node n rest) e
              = wfBound amp ampRank ampBound rest
                  * typein (entryLt n) ⟨_, ndenote_binder_denotes n amp _ hb (hspec e).2.1⟩
                + wfRank amp ampRank ampBound rest
                    ⟨_, (walk_prodNode_fsplit rest amp _).mpr (hspec e).2.2⟩ :=
          fun e => wfRank_node_binder_pos amp ampRank ampBound n rest hb e
            (ndenote_binder_denotes n amp _ hb (hspec e).2.1)
            ((walk_prodNode_fsplit rest amp _).mpr (hspec e).2.2)
        constructor
        · intro e; rw [hval e]; exact mixmul_lt (fb _) (typein_lt_type _ _)
        · intro x y hxy
          rw [hval x, hval y] at hxy
          have hWpos : (0 : Ordinal) < wfBound amp ampRank ampBound rest :=
            zero_le.trans_lt (fb ⟨_, (walk_prodNode_fsplit rest amp _).mpr (hspec x).2.2⟩)
          obtain ⟨hqe, hre⟩ := mixmul_inj hWpos.ne' (fb _) (fb _) hxy
          have hhead : (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) x.1).1
              = (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) y.1).1 :=
            congrArg Subtype.val (typein_injective _ hqe)
          have htail : (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) x.1).2
              = (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) y.1).2 :=
            congrArg Subtype.val (fi hre)
          apply Subtype.ext
          rw [(hspec x).1, (hspec y).1, hhead, htail]
      · rw [Bool.not_eq_true] at hb
        simp only [hb, Bool.false_eq_true, if_false]
        obtain ⟨nb, ni⟩ := wnFaithful n hn
        have hval : ∀ e : {s : Spelling // walk (nsingle (.prod (.node n rest))) amp False s},
            wfRank amp ampRank ampBound (.node n rest) e
              = wfBound amp ampRank ampBound rest
                  * wnRank amp ampRank ampBound n
                      ⟨_, (ndenote_nonbinder n amp _ hb).mp (hspec e).2.1⟩
                + wfRank amp ampRank ampBound rest
                    ⟨_, (walk_prodNode_fsplit rest amp _).mpr (hspec e).2.2⟩ :=
          fun e => wfRank_node_nonbinder_pos amp ampRank ampBound n rest hb e
            ((ndenote_nonbinder n amp _ hb).mp (hspec e).2.1)
            ((walk_prodNode_fsplit rest amp _).mpr (hspec e).2.2)
        constructor
        · intro e; rw [hval e]; exact mixmul_lt (fb _) (nb _)
        · intro x y hxy
          rw [hval x, hval y] at hxy
          have hWpos : (0 : Ordinal) < wfBound amp ampRank ampBound rest :=
            zero_le.trans_lt (fb ⟨_, (walk_prodNode_fsplit rest amp _).mpr (hspec x).2.2⟩)
          obtain ⟨hqe, hre⟩ := mixmul_inj hWpos.ne' (fb _) (fb _) hxy
          have hhead : (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) x.1).1
              = (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) y.1).1 :=
            congrArg Subtype.val (ni hqe)
          have htail : (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) x.1).2
              = (someSplitP (fun p => ndenote n amp p) (fun q => fsplit rest amp q) y.1).2 :=
            congrArg Subtype.val (fi hre)
          apply Subtype.ext
          rw [(hspec x).1, (hspec y).1, hhead, htail]

end

end WithinStageFaithful

/- ================================================================ -/
/- STEP 4c: tie the knot -- the closure rank by recursion on the      -/
/- stage index. Stage `k+1`'s within-rank is 4b's body rank           -/
/- (`wnRank`) over `walk n (stage n k) False`, with the amp-rank set   -/
/- to the closure rank of the earlier stage `k` (its `stage n k`       -/
/- entries) and amp-bound its per-stage bound `csBound n k`. The two   -/
/- are defined together as one pair-valued structural recursion on the -/
/- stage `k` -- the earlier-stage rank is literally the stage-`k` data, -/
/- so the recursion is manifestly well-founded (structural on `ℕ`).    -/
/- ================================================================ -/

open Classical in
/-- The tied knot: at each stage index `k`, the pair of (per-stage
bound, per-stage rank on raw spellings). Stage `0` is empty (`stage n 0`
is `False`), so its bound is `0` and its rank junk `0`. Stage `k+1`
carries an old entry (already in `stage n k`) at its stage-`k` rank, and
ranks a fresh body-spelling (`walk n (stage n k) False`) by 4b's body
rank `wnRank` shifted past the earlier stages' width `csBound n k`, with
the earlier stage's rank/bound supplied as the amp-rank/amp-bound. -/
noncomputable def csData (n : Node) : ℕ → Ordinal × (Spelling → Ordinal)
  | 0 => (0, fun _ => 0)
  | k + 1 =>
      ((csData n k).1
          + wnBound (stage n k) (fun e => (csData n k).2 e.1) (csData n k).1 n,
       fun s =>
        if stage n k s then (csData n k).2 s
        else if h : walk n (stage n k) False s then
          (csData n k).1
            + wnRank (stage n k) (fun e => (csData n k).2 e.1) (csData n k).1 n ⟨s, h⟩
        else 0)

/-- The per-stage closure bound: the total width of all entries first
appearing at stage `< k`. -/
noncomputable def csBound (n : Node) (k : ℕ) : Ordinal := (csData n k).1

/-- The per-stage closure rank on raw spellings (junk `0` off `stage n k`). -/
noncomputable def csRank (n : Node) (k : ℕ) (s : Spelling) : Ordinal := (csData n k).2 s

/- ---- One-step unfolding equations. ---- -/

theorem csBound_zero (n : Node) : csBound n 0 = 0 := rfl

theorem csRank_zero (n : Node) (s : Spelling) : csRank n 0 s = 0 := rfl

theorem csBound_succ (n : Node) (k : ℕ) :
    csBound n (k + 1)
      = csBound n k + wnBound (stage n k) (fun e => csRank n k e.1) (csBound n k) n := rfl

theorem csRank_succ_old (n : Node) (k : ℕ) (s : Spelling) (h : stage n k s) :
    csRank n (k + 1) s = csRank n k s := by
  simp only [csRank, csData, if_pos h]

theorem csRank_succ_new (n : Node) (k : ℕ) (s : Spelling)
    (h1 : ¬ stage n k s) (h2 : walk n (stage n k) False s) :
    csRank n (k + 1) s
      = csBound n k
        + wnRank (stage n k) (fun e => csRank n k e.1) (csBound n k) n ⟨s, h2⟩ := by
  simp only [csRank, csBound, csData, if_neg h1, dif_pos h2]

theorem csRank_succ_none (n : Node) (k : ℕ) (s : Spelling)
    (h1 : ¬ stage n k s) (h2 : ¬ walk n (stage n k) False s) :
    csRank n (k + 1) s = 0 := by
  simp only [csRank, csData, if_neg h1, dif_neg h2]

/- ---- The closure rank on a binder node's entries. ---- -/

/-- The body-recursive closure rank: an entry's rank is its per-stage rank
read at the stage where it first appears. Stage-major by construction (the
`csBound n k` offset separates stages), body-recursive within a stage (4b's
`wnRank`). Defined on every node, meant for binder nodes (where an entry's
`firstStage` is genuine). -/
noncomputable def cRank (n : Node) (e : Entries n) : Ordinal :=
  csRank n (firstStage n e.1) e.1

end L1
