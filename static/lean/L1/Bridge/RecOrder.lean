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
        (if h1 : denotes n (someSplit n (prodNode rest) e.1).1
            then nRank n ⟨_, h1⟩ else 0) * fBound rest
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

/-- Bound contributed by a product's factor list: the product of factor
weights, most significant factor first. -/
noncomputable def fBound : Factors → Ordinal
  | .nil => 1
  | .amp rest => closureBound (nsingle (.prod (.amp rest)))
  | .node n rest =>
      if hasAmpb rest then closureBound (nsingle (.prod (.node n rest)))
      else nBound n * fBound rest

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

end L1
