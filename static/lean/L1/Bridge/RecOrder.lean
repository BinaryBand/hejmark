/- L1 bridge: the body-recursive within-body order (design in
`RecOrder.design.md`).

This module replaces the sanctioned within-body approximation -- `entrySpellLt`
orders a node's entries by raw shortlex -- with an order that recurses into each
constructor's own structure. It is the upstream primitive the rest of
`L1/Bridge/` is framed onto: the enumeration (`entryRecType`), the product and
union type laws, and the transfinite rows (`L1/Bridge/Rows.lean`) all read off
this order, and the superseded spelling-order approximation orders that
Product/Union once carried (`prodLt`, `unionLt`) have been deleted in favour of
it.

This first increment is the reusable core of the design's central move. The
existing bridge files prove `IsWellOrder` by embedding into a `Prod.Lex` of
known well orders; for a recursive order that target is itself recursive and
dependent on which sub-body owns an entry, which is awkward to write. Instead an
order is presented as a rank into the single, non-dependent type `Ordinal`:
`rankLt rank a b := rank a < rank b`. Well-foundedness and transitivity are then
free (they are `<` on `Ordinal`, pulled back), so the entire novelty of the
well-order proof collapses to one obligation -- the rank is injective. The
recursive `entryRank` and its injectivity are the next increment. -/
import L1.Bridge.Split

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
/- is injective, so the spelling orders the bridge builds            -/
/- (`entrySpellLt`, `entryLt`) are instances of the rank framework,  -/
/- not competitors to it.                                            -/
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
/- Shared input to the rank recursions: the fallback bound for a      -/
/- nested closure inside the within-stage recursion (STEP 4b). The    -/
/- rank and bound themselves are defined at the end of this file,     -/
/- after the closure machinery they consume (the 4d-iii swap); the    -/
/- split machinery they run on is `L1/Bridge/Split.lean`.             -/
/- ---------------------------------------------------------------- -/

/-- Bound for a nested-closure fallback block: the order type of the
stage-major `entryLt`. After the 4d-iii swap only the within-stage recursion
(STEP 4b) still ranks a nested, amp-independent closure by this fallback --
the top-level closure branches rank by `cRank` / `cBound`. -/
noncomputable def closureBound (n : Node) : Ordinal := Ordinal.type (entryLt n)

/- ---------------------------------------------------------------- -/
/- STEP 2 support: the faithfulness apparatus -- the `Faithful`     -/
/- bundle, the mixed-radix arithmetic, the subtraction-free         -/
/- skeleton. See RecOrder.design.md, "Why injectivity composes".    -/
/- ---------------------------------------------------------------- -/

/-- Bound invariant plus injectivity, bundled: `rank` lands strictly below
`bound` and is injective (so the induced `rankLt` is a well order). -/
def Faithful {β : Type*} (rank : β → Ordinal) (bound : Ordinal) : Prop :=
  (∀ e, rank e < bound) ∧ Function.Injective rank

/-- Any well order's own `typein` is faithful with bound its order type -- the
leaf base case (a leaf ranks by `entrySpellLt`, bounded by its own order type),
and the nested-closure fallback inside the within-stage recursion (STEP 4b). -/
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

/-- Mixed-radix comparison: with both low digits below the base, positional
comparison is lexicographic -- high digit first, low digit on a tie. The iff
form of `mixmul_lt` / `mixmul_inj`, what turns the product rank's faithfulness
into an order isomorphism. -/
theorem mixmul_lt_iff {W a1 b1 a2 b2 : Ordinal} (hb1 : b1 < W) (hb2 : b2 < W) :
    W * a1 + b1 < W * a2 + b2 ↔ a1 < a2 ∨ (a1 = a2 ∧ b1 < b2) := by
  constructor
  · intro h
    rcases lt_trichotomy a1 a2 with hlt | heq | hgt
    · exact Or.inl hlt
    · subst heq
      exact Or.inr ⟨rfl, (add_lt_add_iff_left _).1 h⟩
    · exact absurd ((mixmul_lt hb2 hgt).trans_le le_self_add) (lt_asymm h)
  · rintro (hlt | ⟨rfl, hb⟩)
    · exact (mixmul_lt hb1 hlt).trans_le le_self_add
    · exact (add_lt_add_iff_left _).2 hb

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

/- ---------------------------------------------------------------- -/
/- STEP 4a: the closure within-stage order -- the stage half.       -/
/- Given ANY within-stage rank bounded by and injective within      -/
/- each stage, the stage-major assembly (ladder offset plus         -/
/- within-stage rank) is an injective rank. See design.md 4a.       -/
/- ---------------------------------------------------------------- -/

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

/- ---------------------------------------------------------------- -/
/- STEP 4b-i: the within-stage body-membership inversions. A        -/
/- stage-`k+1` body-spelling lives in `walk n (stage n k) False`,   -/
/- so the union / fold / product routings restate over an           -/
/- arbitrary amp-set. See RecOrder.design.md 4b-i.                  -/
/- ---------------------------------------------------------------- -/

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

/- ---------------------------------------------------------------- -/
/- STEP 4b-ii-a: the within-stage body recursion -- DEFINITIONS.    -/
/- A parallel copy of the step-2 recursion over `walk n amp         -/
/- False`, parameterized by a supplied earlier-stage rank           -/
/- `(ampRank, ampBound)`. See RecOrder.design.md 4b-ii-a.           -/
/- ---------------------------------------------------------------- -/

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

/- ---------------------------------------------------------------- -/
/- STEP 4b-ii-b: within-stage faithfulness. Given a faithful        -/
/- supplied amp-rank, the within-stage recursion is faithful on     -/
/- the subtraction-free skeleton. See design.md 4b-ii-b.            -/
/- ---------------------------------------------------------------- -/

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

/- ---------------------------------------------------------------- -/
/- STEP 4c: tie the knot -- the closure rank by recursion on the    -/
/- stage index, one pair-valued structural recursion on `Nat`       -/
/- pairing per-stage bound with per-stage rank. See design.md 4c.   -/
/- ---------------------------------------------------------------- -/

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

/- ---------------------------------------------------------------- -/
/- STEP 4d-i: per-stage closure faithfulness -- the union-block     -/
/- disjoint-interval argument run along the stage ladder.           -/
/- See RecOrder.design.md 4d-i.                                     -/
/- ---------------------------------------------------------------- -/

/-- Per-stage closure faithfulness: at every stage index `k`, the per-stage rank
`csRank n k` (restricted to the stage-`k` set) is an injective rank bounded by
`csBound n k`. By induction on `k`: stage `0` is empty; stage `k+1` splits into the
old block (carried at the stage-`k` rank, faithful by the IH, landing `< csBound n k`)
and the fresh block (`walk n (stage n k) False`, ranked by 4b's `wnRank` off the IH
as the amp-rank, landing in `[csBound n k, csBound n (k+1))` by `wnFaithful`). The two
blocks live in disjoint ordinal intervals, so injectivity composes -- the union-block
disjoint-interval argument run along the stage ladder. Needs `nSubfree n` (the
subtraction-free skeleton `wnFaithful` requires). -/
theorem csFaithful (n : Node) (hsub : nSubfree n = true) :
    ∀ k, Faithful (fun e : {s : Spelling // stage n k s} => csRank n k e.1) (csBound n k)
  | 0 =>
      ⟨fun e => absurd e.2 (by rw [stage_zero]; exact not_false),
       fun x _ _ => absurd x.2 (by rw [stage_zero]; exact not_false)⟩
  | k + 1 => by
      obtain ⟨hib, hii⟩ := csFaithful n hsub k
      obtain ⟨hwb, hwi⟩ :=
        wnFaithful (stage n k) (fun e => csRank n k e.1) (csBound n k)
          (csFaithful n hsub k) n hsub
      have hle : csBound n k ≤ csBound n (k + 1) := by rw [csBound_succ]; exact le_self_add
      have hnew : ∀ z : {s : Spelling // stage n (k + 1) s},
          ¬ stage n k z.1 → walk n (stage n k) False z.1 := by
        intro z hz
        have hz2 := z.2
        rw [stage_succ] at hz2
        exact hz2.resolve_left hz
      constructor
      · intro e
        show csRank n (k + 1) e.1 < csBound n (k + 1)
        by_cases h : stage n k e.1
        · rw [csRank_succ_old n k e.1 h]
          exact (hib ⟨e.1, h⟩).trans_le hle
        · have h2 := hnew e h
          rw [csRank_succ_new n k e.1 h h2, csBound_succ]
          exact (add_lt_add_iff_left _).2 (hwb ⟨e.1, h2⟩)
      · intro x y hxy
        change csRank n (k + 1) x.1 = csRank n (k + 1) y.1 at hxy
        by_cases hx : stage n k x.1 <;> by_cases hy : stage n k y.1
        · rw [csRank_succ_old n k x.1 hx, csRank_succ_old n k y.1 hy] at hxy
          have hval := congrArg Subtype.val (hii (a₁ := ⟨x.1, hx⟩) (a₂ := ⟨y.1, hy⟩) hxy)
          exact Subtype.ext hval
        · rw [csRank_succ_old n k x.1 hx, csRank_succ_new n k y.1 hy (hnew y hy)] at hxy
          have hlt : csRank n k x.1 < csBound n k := hib ⟨x.1, hx⟩
          rw [hxy] at hlt
          exact absurd hlt (not_lt.2 le_self_add)
        · rw [csRank_succ_new n k x.1 hx (hnew x hx), csRank_succ_old n k y.1 hy] at hxy
          have hlt : csRank n k y.1 < csBound n k := hib ⟨y.1, hy⟩
          rw [← hxy] at hlt
          exact absurd hlt (not_lt.2 le_self_add)
        · rw [csRank_succ_new n k x.1 hx (hnew x hx),
              csRank_succ_new n k y.1 hy (hnew y hy)] at hxy
          have heq := (add_left_cancel_iff).1 hxy
          have hval := congrArg Subtype.val (hwi (a₁ := ⟨x.1, hnew x hx⟩) (a₂ := ⟨y.1, hnew y hy⟩) heq)
          exact Subtype.ext hval

/- ---------------------------------------------------------------- -/
/- STEP 4d-ii: entry-level total-bound closure faithfulness, plus   -/
/- the fold-of-binder reinterpretation. Purely additive; the swap   -/
/- into the rank recursion is 4d-iii. See design.md 4d-ii.          -/
/- ---------------------------------------------------------------- -/

/-- The total closure bound: the sup over stages of the per-stage bounds
`csBound n k` -- the closure's order type as seen by the recursive rank. -/
noncomputable def cBound (n : Node) : Ordinal := ⨆ k, csBound n k

theorem csBound_le_cBound (n : Node) (k : ℕ) : csBound n k ≤ cBound n :=
  Ordinal.le_iSup (fun k => csBound n k) k

/-- Per-stage bounds grow along the ladder: each successor adds the fresh
block's width on the right (`csBound_succ`). -/
theorem csBound_mono (n : Node) {j k : ℕ} (h : j ≤ k) :
    csBound n j ≤ csBound n k := by
  induction k, h using Nat.le_induction with
  | base => exact le_rfl
  | succ k hk ih => rw [csBound_succ]; exact ih.trans le_self_add

/-- Cross-stage stabilization: once a spelling has appeared, every later
stage carries it at the same rank (`csRank_succ_old` iterated). -/
theorem csRank_stable (n : Node) {j k : ℕ} (h : j ≤ k) (s : Spelling)
    (hs : stage n j s) : csRank n k s = csRank n j s := by
  induction k, h using Nat.le_induction with
  | base => rfl
  | succ k hk ih => rw [csRank_succ_old n k s (stage_mono_le n j k s hk hs), ih]

/-- Stabilization read at the first appearance: any stage that carries `s`
carries it at its first-stage rank -- the per-stage rank IS the entry rank
`cRank` wherever it is defined. -/
theorem csRank_firstStage (n : Node) {k : ℕ} (s : Spelling) (h : stage n k s) :
    csRank n k s = csRank n (firstStage n s) s :=
  csRank_stable n (firstStage_le n s h) s (firstStage_stage n s ⟨k, h⟩)

/-- A fresh entry ranks at or past the earlier stages' width: the fresh block
starts at the offset `csBound n k` (`csRank_succ_new`). -/
theorem csBound_le_csRank_fresh (n : Node) (k : ℕ) (s : Spelling)
    (h1 : ¬ stage n k s) (h2 : walk n (stage n k) False s) :
    csBound n k ≤ csRank n (k + 1) s := by
  rw [csRank_succ_new n k s h1 h2]
  exact le_self_add

/-- Stage-major disjointness at the entry level: a strictly earlier first
appearance is a strictly smaller entry rank. The earlier entry lands below its
stage's bound (4d-i), the later entry's stage opens at or past that bound
(`csBound_le_csRank_fresh` through `csBound_mono`) -- the disjoint-interval
argument read across two different stages. -/
theorem cRank_lt_of_firstStage_lt (n : Node) (hsub : nSubfree n = true)
    {x y : Entries n} (hx : stage n (firstStage n x.1) x.1)
    (hy : stage n (firstStage n y.1) y.1)
    (hlt : firstStage n x.1 < firstStage n y.1) :
    cRank n x < cRank n y := by
  cases hjy : firstStage n y.1 with
  | zero => omega
  | succ m =>
      have hnotm : ¬ stage n m y.1 := fun hm =>
        absurd (firstStage_le n y.1 hm) (by omega)
      have hy' : stage n (m + 1) y.1 := by rw [← hjy]; exact hy
      rw [stage_succ] at hy'
      have hw : walk n (stage n m) False y.1 := hy'.resolve_left hnotm
      have h1 : cRank n x < csBound n (firstStage n x.1) :=
        (csFaithful n hsub (firstStage n x.1)).1 ⟨x.1, hx⟩
      have h2 : csBound n (firstStage n x.1) ≤ csBound n m :=
        csBound_mono n (by omega)
      have h3 : csBound n m ≤ csRank n (m + 1) y.1 :=
        csBound_le_csRank_fresh n m y.1 hnotm hw
      have h4 : csRank n (m + 1) y.1 = cRank n y := by
        show csRank n (m + 1) y.1 = csRank n (firstStage n y.1) y.1
        rw [hjy]
      exact (h1.trans_le h2).trans_le (h3.trans_eq h4)

/-- Entry-level closure faithfulness: on a genuine binder node (`bindsb`), the
body-recursive closure rank `cRank` is injective and lands below the total
bound `cBound`. Different first stages separate by stage-major disjointness
(`cRank_lt_of_firstStage_lt`); a shared first stage reduces to 4d-i's
within-stage faithfulness (`csFaithful`). This is what replaces
`faithful_typein` on the closure fallbacks in 4d-iii. -/
theorem cFaithful (n : Node) (hb : bindsb n = true) (hsub : nSubfree n = true) :
    Faithful (cRank n) (cBound n) := by
  have hstage : ∀ e : Entries n, stage n (firstStage n e.1) e.1 := fun e =>
    firstStage_stage n e.1 ((ndenote_binder n (fun _ => False) e.1 hb).mp e.2)
  constructor
  · intro e
    exact ((csFaithful n hsub (firstStage n e.1)).1 ⟨e.1, hstage e⟩).trans_le
      (csBound_le_cBound n (firstStage n e.1))
  · intro x y hxy
    rcases lt_trichotomy (firstStage n x.1) (firstStage n y.1) with hlt | heq | hgt
    · exact absurd hxy
        (cRank_lt_of_firstStage_lt n hsub (hstage x) (hstage y) hlt).ne
    · have hsy : stage n (firstStage n x.1) y.1 := by rw [heq]; exact hstage y
      have hxy' : csRank n (firstStage n x.1) x.1
          = csRank n (firstStage n x.1) y.1 := by
        show cRank n x = csRank n (firstStage n x.1) y.1
        rw [hxy]
        show csRank n (firstStage n y.1) y.1 = csRank n (firstStage n x.1) y.1
        rw [heq]
      have hval := congrArg Subtype.val
        ((csFaithful n hsub (firstStage n x.1)).2
          (a₁ := ⟨x.1, hstage x⟩) (a₂ := ⟨y.1, hsy⟩) hxy')
      exact Subtype.ext hval
    · exact absurd hxy.symm
        (cRank_lt_of_firstStage_lt n hsub (hstage y) (hstage x) hgt).ne

/- ---- The fold-of-binder reinterpretation. ---- -/

/-- A fold-of-binder entry is exactly an inner-closure entry: the fold node
itself binds nothing (the fold captures the `&`), so its denotation is
`spells_fold`'s closure branch, which is the binder's own denotation. -/
theorem denotes_fold_binder (inner : Node) (hb : bindsb inner = true)
    (s : Spelling) :
    denotes (nsingle (.fold inner)) s ↔ denotes inner s := by
  have hnode : bindsb (nsingle (.fold inner)) = false := by
    simp [nsingle, bindsb, freeAmpb]
  show ndenote (nsingle (.fold inner)) (fun _ => False) s
    ↔ ndenote inner (fun _ => False) s
  rw [ndenote_nonbinder _ _ _ hnode, ndenote_binder _ _ _ hb,
    walk_single_fold, false_or, spells_fold, if_pos hb]

/-- Route a fold-of-binder entry to the inner closure's carrier -- same
spelling, membership carried across `denotes_fold_binder`. -/
def foldBinderReinterp (inner : Node) (hb : bindsb inner = true)
    (e : Entries (nsingle (.fold inner))) : Entries inner :=
  ⟨e.1, (denotes_fold_binder inner hb e.1).mp e.2⟩

theorem foldBinderReinterp_injective (inner : Node) (hb : bindsb inner = true) :
    Function.Injective (foldBinderReinterp inner hb) := by
  intro x y h
  have hval := congrArg Subtype.val h
  exact Subtype.ext hval

/-- The routed rank is faithful: a fold-of-binder entry ranks at its inner
closure's `cRank`, bounded by the inner closure's `cBound` -- the branch
4d-iii installs on `mRank (.fold inner)` for a binder `inner`. -/
theorem foldBinderFaithful (inner : Node) (hb : bindsb inner = true)
    (hsub : nSubfree inner = true) :
    Faithful (fun e => cRank inner (foldBinderReinterp inner hb e))
      (cBound inner) :=
  ⟨fun e => (cFaithful inner hb hsub).1 (foldBinderReinterp inner hb e),
   fun _ _ h => foldBinderReinterp_injective inner hb
     ((cFaithful inner hb hsub).2 h)⟩

/- ---------------------------------------------------------------- -/
/- STEP 2 + 4d-iii: the rank and bound, defined together in one     -/
/- structural recursion, and their faithfulness. Reordering         -/
/- constructors compose sub-ranks into disjoint ordinal intervals;  -/
/- a closure ranks by `cRank` / `cBound` -- the 4d-iii swap.        -/
/- See RecOrder.design.md 4d-iii.                                   -/
/- ---------------------------------------------------------------- -/

open Classical in
mutual

/-- Rank of an entry of a one-member node. -/
noncomputable def mRank : (m : Member) → Entries (nsingle m) → Ordinal
  | .face t, e => typein (entrySpellLt (nsingle (.face t))) e
  | .range lo hi, e => typein (entrySpellLt (nsingle (.range lo hi))) e
  | .final lo, e => typein (entrySpellLt (nsingle (.final lo))) e
  | .amp, e => cRank (nsingle .amp) e
  | .sub inner, e => typein (entrySpellLt (nsingle (.sub inner))) e
  | .fold inner, e =>
      if hb : bindsb inner = true then cRank inner (foldBinderReinterp inner hb e)
      else if h : denotes inner e.1 then nRank inner ⟨e.1, h⟩ else 0
  | .prod fs, e =>
      if hasAmpb fs then cRank (nsingle (.prod fs)) e
      else fRank fs e

/-- Rank of an entry of a node (union spine): first-owner, body-major. -/
noncomputable def nRank : (n : Node) → Entries n → Ordinal
  | .nil, e => absurd e.2 (by
      simp only [denotes, ndenote, bindsb, Bool.false_eq_true, if_false, walk_nil]
      exact not_false)
  | .cons m rest, e =>
      if bindsb (.cons m rest) then cRank (.cons m rest) e
      else if h : denotes (nsingle m) e.1 then mRank m ⟨e.1, h⟩
           else if h2 : denotes rest e.1 then mBound m + nRank rest ⟨e.1, h2⟩ else 0

/-- Rank of an entry of a product, positional (mixed radix) over factor pieces. -/
noncomputable def fRank : (fs : Factors) → Entries (nsingle (.prod fs)) → Ordinal
  | .nil, e => typein (entrySpellLt (nsingle (.prod .nil))) e
  | .amp rest, e => cRank (nsingle (.prod (.amp rest))) e
  | .node n rest, e =>
      if hasAmpb rest then cRank (nsingle (.prod (.node n rest))) e
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
  | .amp => cBound (nsingle .amp)
  | .sub inner => entriesType (nsingle (.sub inner))
  | .fold inner =>
      if bindsb inner then cBound inner else nBound inner + 1
  | .prod fs => if hasAmpb fs then cBound (nsingle (.prod fs)) else fBound fs

/-- Bound contributed by a node: the sum of its members' block widths. -/
noncomputable def nBound : Node → Ordinal
  | .nil => 0
  | .cons m rest =>
      if bindsb (.cons m rest) then cBound (.cons m rest) else mBound m + nBound rest

/-- Bound contributed by a product's factor list: the mixed-radix width, tail
base times head count. The head is the major digit (`fRank` ranks an entry as
`fBound rest * headRank + tailRank` with `tailRank < fBound rest`), so the base
`fBound rest` multiplies on the left -- ordinal `*` makes the right factor major,
so `base * count`, not `count * base`, is the width the head ranges over. -/
noncomputable def fBound : Factors → Ordinal
  | .nil => entriesType (nsingle (.prod .nil))
  | .amp rest => cBound (nsingle (.prod (.amp rest)))
  | .node n rest =>
      if hasAmpb rest then cBound (nsingle (.prod (.node n rest)))
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
  | .amp, _ => by simp only [mRank, mBound]; exact cFaithful (nsingle .amp) rfl rfl
  | .sub _, h => absurd h (by simp [mSubfree])
  | .fold inner, h => by
      by_cases hb : bindsb inner = true
      · simp only [mRank, mBound, dif_pos hb, if_pos hb]
        exact foldBinderFaithful inner hb (by simpa only [mSubfree] using h)
      · rw [Bool.not_eq_true] at hb
        have hbf : ¬ (bindsb inner = true) := by simp [hb]
        have hin : nSubfree inner = true := by simpa only [mSubfree] using h
        obtain ⟨ib, ii⟩ := nFaithful inner hin
        constructor
        · intro e
          simp only [mRank, mBound, dif_neg hbf, if_neg hbf]
          by_cases hd : denotes inner e.1
          · rw [dif_pos hd]; exact (ib ⟨e.1, hd⟩).trans_le le_self_add
          · rw [dif_neg hd]; exact zero_lt_one.trans_le le_add_self
        · intro x y hxy
          simp only [mRank, dif_neg hbf] at hxy
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
      · have hfs : fSubfree fs = true := by simpa only [mSubfree] using h
        have hbn : bindsb (nsingle (.prod fs)) = true := by
          simp [nsingle, bindsb, freeAmpb, hna]
        have hsub : nSubfree (nsingle (.prod fs)) = true := by
          simpa [nsingle, nSubfree, mSubfree] using hfs
        simp only [mRank, mBound, hna, if_true]
        exact cFaithful _ hbn hsub
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
      · simp only [nRank, nBound, hb, if_true]
        exact cFaithful (.cons m rest) hb h
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
  | .amp rest, h => by
      have hsub : nSubfree (nsingle (.prod (.amp rest))) = true := by
        simpa [nsingle, nSubfree, mSubfree, fSubfree] using h
      simp only [fRank, fBound]
      exact cFaithful _ rfl hsub
  | .node n rest, h => by
      by_cases hna : hasAmpb rest = true
      · have hbn : bindsb (nsingle (.prod (.node n rest))) = true := by
          simp [nsingle, bindsb, freeAmpb, hasAmpb, hna]
        have hsub : nSubfree (nsingle (.prod (.node n rest))) = true := by
          simpa [nsingle, nSubfree, mSubfree, fSubfree] using h
        simp only [fRank, fBound, hna, if_true]
        exact cFaithful _ hbn hsub
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
            IsSplit n (prodNode rest) e.1 (someSplit n (prodNode rest) e.1) :=
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

/- ---- The recursive entries enumeration (STEP 5a): the order type of the -/
/- new order, the quantity the migrated row theorems compute.              -/

/-- The body-recursive entries enumeration: the order type of `entryRecLt`,
read on the subtraction-free skeleton where `entryRecLt_isWellOrder` makes it
a well order (junk `0` off it). This is the enumeration that replaces the
spelling-order `entriesType` in the migrated row theorems; on a leaf the two
agree (`entryRecType_leaf`). -/
noncomputable def entryRecType (n : Node) : Ordinal :=
  if h : nSubfree n = true then
    @Ordinal.type _ (entryRecLt n) (entryRecLt_isWellOrder n h)
  else 0

/-- Unfolding on the subtraction-free skeleton. -/
theorem entryRecType_def (n : Node) (h : nSubfree n = true) :
    entryRecType n
      = @Ordinal.type _ (entryRecLt n) (entryRecLt_isWellOrder n h) :=
  dif_pos h

/-- Leaf agreement at the enumeration level: on a leaf member the recursive
enumeration is the spelling enumeration -- `entryRecLt_leaf` read through a
reflexive order isomorphism. -/
theorem entryRecType_leaf (m : Member) (hb : bindsb (nsingle m) = false)
    (hsub : mSubfree m = true)
    (hm : ∀ e, mRank m e = Ordinal.typein (entrySpellLt (nsingle m)) e) :
    entryRecType (nsingle m) = entriesType (nsingle m) := by
  have hn : nSubfree (nsingle m) = true := by
    simp [nsingle, nSubfree, hsub]
  haveI := entryRecLt_isWellOrder (nsingle m) hn
  rw [entryRecType_def (nsingle m) hn]
  refine Ordinal.type_eq.mpr ⟨⟨Equiv.refl _, ?_⟩⟩
  intro a b
  exact iff_of_eq
    (congrFun (congrFun (entryRecLt_leaf m hb hm) a) b).symm

theorem entryRecType_face (t : Spelling) :
    entryRecType (nsingle (.face t)) = entriesType (nsingle (.face t)) :=
  entryRecType_leaf (.face t) (by simp [nsingle, bindsb, freeAmpb]) rfl
    (fun e => by simp only [mRank])

theorem entryRecType_range (lo hi : Code) :
    entryRecType (nsingle (.range lo hi)) = entriesType (nsingle (.range lo hi)) :=
  entryRecType_leaf (.range lo hi) (by simp [nsingle, bindsb, freeAmpb]) rfl
    (fun e => by simp only [mRank])

theorem entryRecType_final (lo : Spelling) :
    entryRecType (nsingle (.final lo)) = entriesType (nsingle (.final lo)) :=
  entryRecType_leaf (.final lo) (by simp [nsingle, bindsb, freeAmpb]) rfl
    (fun e => by simp only [mRank])

/- ---------------------------------------------------------------- -/
/- STEP 5b: the product law on the recursive order -- under unique  -/
/- splits the mixed-radix comparison turns the rank arithmetic      -/
/- into a lex order. See RecOrder.design.md 5.                      -/
/- ---------------------------------------------------------------- -/

/-- The empty product denotes exactly the empty spelling -- the tail base
case of the factor recursion (`fsplit_fnil` read at the `denotes` level). -/
theorem prodNil_denotes_iff (s : Spelling) :
    denotes (prodNode .nil) s ↔ s = [] := by
  rw [denotes_prodNode_fsplit .nil rfl s, fsplit_fnil]

theorem prodNil_denotes_nil : denotes (prodNode .nil) [] :=
  (prodNil_denotes_iff []).mpr rfl

/-- A singleton factor list wears exactly its factor's language: the tail
piece of its split is forced empty, so the head piece is the whole entry. -/
theorem prodTail_denotes_iff (b : Node) (q : Spelling) :
    denotes (prodNode (.node b .nil)) q ↔ denotes b q := by
  rw [prodNode_node_split b .nil rfl q]
  constructor
  · rintro ⟨q1, q2, rfl, hq1, hq2⟩
    rw [prodNil_denotes_iff] at hq2
    subst hq2
    rwa [List.append_nil]
  · intro hq
    exact ⟨q, [], (List.append_nil q).symm, hq, prodNil_denotes_nil⟩

/-- The recursion's split choice on a binary-product entry is a genuine
head/tail split (`prodNode_node_split_exists` fed to `someSplit_isHT`). -/
theorem prod2_someSplit_isHT (a b : Node) (e : Entries (prod2 a b)) :
    IsSplit a (prodNode (.node b .nil)) e.1
      (someSplit a (prodNode (.node b .nil)) e.1) :=
  someSplit_isHT a (prodNode (.node b .nil)) e.1
    (prodNode_node_split_exists (rfl : hasAmpb (Factors.node b Factors.nil) = false) e)

/-- The head/tail factor entries of a binary-product entry, carved by the
recursion's own split choice `someSplit` (`L1/Bridge/Split.lean`), which is
also what `prod2_collision_settled` names as the owning claimant. -/
noncomputable def prod2RecPieces (a b : Node) (e : Entries (prod2 a b)) :
    Entries a × Entries b :=
  (⟨(someSplit a (prodNode (.node b .nil)) e.1).1, (prod2_someSplit_isHT a b e).2.1⟩,
   ⟨(someSplit a (prodNode (.node b .nil)) e.1).2,
     (prodTail_denotes_iff b _).mp (prod2_someSplit_isHT a b e).2.2⟩)

/-- Injective with no uniqueness hypothesis -- the owning split reconstructs
its entry (`e.1 = p ++ q`). -/
theorem prod2RecPieces_injective (a b : Node) :
    Function.Injective (prod2RecPieces a b) := by
  intro x y hxy
  simp only [prod2RecPieces, Prod.mk.injEq, Subtype.mk.injEq] at hxy
  apply Subtype.ext
  rw [(prod2_someSplit_isHT a b x).1, (prod2_someSplit_isHT a b y).1, hxy.1, hxy.2]

/-- Under unique splits the recursion's split choice is the given split --
the pinning that makes the pieces map surjective. -/
theorem prod2_someSplit_eq (a b : Node)
    (huniq : ∀ s pq pq', IsSplit a b s pq → IsSplit a b s pq' → pq = pq')
    {s p q : Spelling} (hs : s = p ++ q) (hp : denotes a p) (hq : denotes b q) :
    someSplit a (prodNode (.node b .nil)) s = (p, q) := by
  have hex : ∃ pq, IsSplit a (prodNode (.node b .nil)) s pq :=
    ⟨(p, q), hs, hp, (prodTail_denotes_iff b q).mpr hq⟩
  have hht := someSplit_isHT a (prodNode (.node b .nil)) s hex
  exact huniq s _ (p, q)
    ⟨hht.1, hht.2.1, (prodTail_denotes_iff b _).mp hht.2.2⟩ ⟨hs, hp, hq⟩

/-- On the singleton tail the split choice is forced: the tail piece must be
empty, so the head piece is the whole entry -- no uniqueness hypothesis. -/
theorem someSplit_prodNil_eq (b : Node) {q : Spelling} (hbq : denotes b q) :
    someSplit b (prodNode .nil) q = (q, []) := by
  have hex : ∃ pq, IsSplit b (prodNode .nil) q pq :=
    ⟨(q, []), (List.append_nil q).symm, hbq, prodNil_denotes_nil⟩
  have hht := someSplit_isHT b (prodNode .nil) q hex
  have h2 : (someSplit b (prodNode .nil) q).2 = [] :=
    (prodNil_denotes_iff _).mp hht.2.2
  have h1 : (someSplit b (prodNode .nil) q).1 = q := by
    have hq := hht.1
    rw [h2, List.append_nil] at hq
    exact hq.symm
  exact Prod.ext h1 h2

/-- The constant low-digit pad every binary-product rank carries: the rank of
the forced-empty tail-of-tail piece in the empty product's spelling order. -/
noncomputable def prodNilRank : Ordinal :=
  typein (entrySpellLt (nsingle (.prod .nil))) ⟨[], prodNil_denotes_nil⟩

theorem prodNilRank_lt : prodNilRank < fBound .nil := by
  simp only [prodNilRank, fBound, entriesType]
  exact typein_lt_type _ _

/-- The singleton-tail rank collapses: the forced split `(q, [])` makes the
rank the factor's own rank plus the constant pad. -/
theorem fRank_node_nil (b : Node) (q : Spelling)
    (hq : denotes (prodNode (.node b .nil)) q) (hbq : denotes b q) :
    fRank (.node b .nil) ⟨q, hq⟩ = fBound .nil * nRank b ⟨q, hbq⟩ + prodNilRank := by
  have hpin := someSplit_prodNil_eq b hbq
  have h1 : denotes b (someSplit b (prodNode .nil) q).1 := by
    rw [hpin]; exact hbq
  have h2 : denotes (prodNode .nil) (someSplit b (prodNode .nil) q).2 := by
    rw [hpin]; exact prodNil_denotes_nil
  have hval : fRank (.node b .nil) ⟨q, hq⟩
      = fBound .nil * nRank b ⟨(someSplit b (prodNode .nil) q).1, h1⟩
        + fRank .nil ⟨(someSplit b (prodNode .nil) q).2, h2⟩ :=
    fRank_node_nb rfl ⟨q, hq⟩ h1 h2
  have e1 : (⟨(someSplit b (prodNode .nil) q).1, h1⟩ : Entries b) = ⟨q, hbq⟩ :=
    Subtype.ext (congrArg Prod.fst hpin)
  have e2 : (⟨(someSplit b (prodNode .nil) q).2, h2⟩ : Entries (nsingle (.prod .nil)))
      = ⟨[], prodNil_denotes_nil⟩ :=
    Subtype.ext (congrArg Prod.snd hpin)
  rw [hval, e1, e2]
  simp only [fRank, prodNilRank]

/-- The binary-product rank in closed mixed-radix form: tail-width times the
head factor's rank, plus the tail factor's rank scaled past the constant pad
-- `fRank_node_nb` read twice through the recursion's split choice. -/
theorem entryRank_prod2 (a b : Node) (e : Entries (prod2 a b)) :
    entryRank (prod2 a b) e
      = fBound (.node b .nil) * entryRank a (prod2RecPieces a b e).1
        + (fBound .nil * entryRank b (prod2RecPieces a b e).2 + prodNilRank) := by
  have hht := prod2_someSplit_isHT a b e
  have h1 : entryRank (prod2 a b) e
      = mRank (.prod (.node a (.node b .nil))) ⟨e.1, e.2⟩ :=
    nRank_cons_first (prod2_bindsb a b) e e.2
  have h2 : mRank (.prod (.node a (.node b .nil))) ⟨e.1, e.2⟩
      = fRank (.node a (.node b .nil)) ⟨e.1, e.2⟩ := by
    have hna : hasAmpb (Factors.node a (Factors.node b Factors.nil)) = false := rfl
    rw [mRank]
    simp only [hna, Bool.false_eq_true, if_false]
  have h3 : fRank (.node a (.node b .nil)) ⟨e.1, e.2⟩
      = fBound (.node b .nil)
          * nRank a ⟨(someSplit a (prodNode (.node b .nil)) e.1).1, hht.2.1⟩
        + fRank (.node b .nil)
            ⟨(someSplit a (prodNode (.node b .nil)) e.1).2, hht.2.2⟩ :=
    fRank_node_nb rfl ⟨e.1, e.2⟩ hht.2.1 hht.2.2
  have h4 : fRank (.node b .nil)
      ⟨(someSplit a (prodNode (.node b .nil)) e.1).2, hht.2.2⟩
      = fBound .nil * nRank b ⟨(someSplit a (prodNode (.node b .nil)) e.1).2,
            (prodTail_denotes_iff b _).mp hht.2.2⟩ + prodNilRank :=
    fRank_node_nil b _ hht.2.2 ((prodTail_denotes_iff b _).mp hht.2.2)
  rw [h1, h2, h3, h4]
  rfl

/-- The comparison law: the binary-product recursive order compares head
ranks first, tail ranks on a tie -- the two mixed-radix layers read through
`mixmul_lt_iff`, the constant pad cancelling on the low digit. -/
theorem entryRecLt_prod2_iff (a b : Node) (hsb : nSubfree b = true)
    (x y : Entries (prod2 a b)) :
    entryRecLt (prod2 a b) x y
      ↔ (entryRank a (prod2RecPieces a b x).1 < entryRank a (prod2RecPieces a b y).1
        ∨ (entryRank a (prod2RecPieces a b x).1 = entryRank a (prod2RecPieces a b y).1
            ∧ entryRank b (prod2RecPieces a b x).2 < entryRank b (prod2RecPieces a b y).2)) := by
  have hT : ∀ e : Entries (prod2 a b),
      fBound .nil * entryRank b (prod2RecPieces a b e).2 + prodNilRank
        < fBound (.node b .nil) := by
    intro e
    rw [fBound_node_nb (rfl : hasAmpb Factors.nil = false)]
    exact mixmul_lt prodNilRank_lt (entryRank_lt_entryBound b hsb (prod2RecPieces a b e).2)
  show entryRank (prod2 a b) x < entryRank (prod2 a b) y ↔ _
  rw [entryRank_prod2 a b x, entryRank_prod2 a b y, mixmul_lt_iff (hT x) (hT y),
    mixmul_lt_iff prodNilRank_lt prodNilRank_lt]
  simp only [lt_self_iff_false, and_false, or_false]

/-- The product law: under unique splits the recursive order on a binary
product is the lex product of the factors' recursive orders -- the recursive
analogue of `prodSplitIso`, with the recursion's own split choice as the
pieces map. -/
noncomputable def prod2RecIso (a b : Node) (hsa : nSubfree a = true)
    (hsb : nSubfree b = true)
    (huniq : ∀ s pq pq', IsSplit a b s pq → IsSplit a b s pq' → pq = pq') :
    entryRecLt (prod2 a b) ≃r Prod.Lex (entryRecLt a) (entryRecLt b) where
  toEquiv := Equiv.ofBijective (prod2RecPieces a b) (by
    refine ⟨prod2RecPieces_injective a b, ?_⟩
    rintro ⟨⟨p, hp⟩, ⟨q, hq⟩⟩
    have hd : denotes (prod2 a b) (p ++ q) :=
      (prod2_denotes_iff a b _).mpr ⟨p, q, rfl, hp, hq⟩
    have hpin : someSplit a (prodNode (.node b .nil)) (p ++ q) = (p, q) :=
      prod2_someSplit_eq a b huniq rfl hp hq
    refine ⟨⟨p ++ q, hd⟩, ?_⟩
    simp only [prod2RecPieces]
    exact Prod.ext (Subtype.ext (congrArg Prod.fst hpin))
      (Subtype.ext (congrArg Prod.snd hpin)))
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply, Prod.lex_def]
    rw [entryRecLt_prod2_iff a b hsb x y]
    constructor
    · rintro (h | ⟨heq, h⟩)
      · exact Or.inl h
      · exact Or.inr ⟨congrArg (entryRank a) heq, h⟩
    · rintro (h | ⟨heq, h⟩)
      · exact Or.inl h
      · exact Or.inr ⟨entryRank_injective a hsa heq, h⟩

/-- The product law on the recursive enumeration: with unique splits a binary
product enumerates as the ordinal product of its factors' recursive
enumerations, most significant factor on the left of the syntax and the right
of the `*` -- the migration replacement for `prodLt_type_of_unique_splits`. -/
theorem entryRecType_prod2 (a b : Node) (hsa : nSubfree a = true)
    (hsb : nSubfree b = true)
    (huniq : ∀ s pq pq', IsSplit a b s pq → IsSplit a b s pq' → pq = pq') :
    entryRecType (prod2 a b) = entryRecType b * entryRecType a := by
  have hsub : nSubfree (prod2 a b) = true := by
    simp [prod2, nsingle, nSubfree, mSubfree, fSubfree, hsa, hsb]
  haveI := entryRecLt_isWellOrder a hsa
  haveI := entryRecLt_isWellOrder b hsb
  haveI := entryRecLt_isWellOrder (prod2 a b) hsub
  rw [entryRecType_def (prod2 a b) hsub, entryRecType_def a hsa, entryRecType_def b hsb]
  exact (Ordinal.type_eq.mpr ⟨prod2RecIso a b hsa hsb huniq⟩).trans
    (type_prod_lex (entryRecLt b) (entryRecLt a))

/- ---------------------------------------------------------------- -/
/- STEP 5c: the union law on the recursive order -- the cons-spine  -/
/- block law iterated along the first body's spine, assembled into  -/
/- an iso onto the lex sum. See RecOrder.design.md 5.               -/
/- ---------------------------------------------------------------- -/

/-- The empty node denotes nothing -- the base of the spine induction. -/
theorem denotes_nnil (s : Spelling) : ¬ denotes Node.nil s := by
  simp only [denotes, ndenote, bindsb, Bool.false_eq_true, if_false, walk_nil]
  exact not_false

/-- Deep subtraction-freeness is closed under union: the appended spine is the
two spines' members in sequence. -/
theorem nSubfree_napp : ∀ (n1 n2 : Node), nSubfree n1 = true →
    nSubfree n2 = true → nSubfree (napp n1 n2) = true
  | .nil, _, _, h2 => h2
  | .cons m rest, n2, h1, h2 => by
      have hcomp : mSubfree m = true ∧ nSubfree rest = true := by
        simpa only [nSubfree, Bool.and_eq_true] using h1
      simpa only [napp, nSubfree, Bool.and_eq_true] using
        ⟨hcomp.1, nSubfree_napp rest n2 hcomp.2 h2⟩

/-- The first block of the union rank: an entry the first body claims ranks at
its first-body rank -- `nRank_cons_first` iterated along the first body's
spine (each unclaimed head member adds the same `mBound` offset on both
sides). -/
theorem nRank_napp_first : ∀ (n1 n2 : Node), bindsb n1 = false →
    bindsb n2 = false → nSubfree n1 = true → nSubfree n2 = true →
    ∀ (e : Entries (napp n1 n2)) (h1 : denotes n1 e.1),
      nRank (napp n1 n2) e = nRank n1 ⟨e.1, h1⟩
  | .nil, _, _, _, _, _, e, h1 => absurd h1 (denotes_nnil e.1)
  | .cons m rest, n2, hb1, hb2, hs1, hs2, e, h1 => by
      have hbcomp : freeAmpb m = false ∧ bindsb rest = false := by
        rw [bindsb, Bool.or_eq_false_iff] at hb1
        exact hb1
      have hbm : bindsb (nsingle m) = false := by
        simp only [nsingle, bindsb, Bool.or_false]
        exact hbcomp.1
      have hbr : bindsb rest = false := hbcomp.2
      have hcomp : mSubfree m = true ∧ nSubfree rest = true := by
        simpa only [nSubfree, Bool.and_eq_true] using hs1
      have hban : bindsb (napp rest n2) = false := by
        rw [bindsb_napp, hbr, hb2]
        rfl
      have hbc : bindsb (Node.cons m (napp rest n2)) = false := by
        rw [bindsb, Bool.or_eq_false_iff]
        exact ⟨hbcomp.1, hban⟩
      by_cases hA : denotes (nsingle m) e.1
      · have hL : nRank (napp (.cons m rest) n2) e = mRank m ⟨e.1, hA⟩ :=
          nRank_cons_first hbc e hA
        have hR : nRank (.cons m rest) ⟨e.1, h1⟩ = mRank m ⟨e.1, hA⟩ :=
          nRank_cons_first hb1 ⟨e.1, h1⟩ hA
        rw [hL, hR]
      · have hrest2 : denotes (napp rest n2) e.1 :=
          ((denotes_napp_iff (nsingle m) (napp rest n2) hbm hban
            (subfreeb_napp rest n2 (nSubfree_subfreeb rest hcomp.2)
              (nSubfree_subfreeb n2 hs2)) e.1).mp e.2).resolve_left hA
        have hrest1 : denotes rest e.1 :=
          ((denotes_napp_iff (nsingle m) rest hbm hbr
            (nSubfree_subfreeb rest hcomp.2) e.1).mp h1).resolve_left hA
        have hL : nRank (napp (.cons m rest) n2) e
            = mBound m + nRank (napp rest n2) ⟨e.1, hrest2⟩ :=
          nRank_cons_rest hbc e hA hrest2
        have hR : nRank (.cons m rest) ⟨e.1, h1⟩
            = mBound m + nRank rest ⟨e.1, hrest1⟩ :=
          nRank_cons_rest hb1 ⟨e.1, h1⟩ hA hrest1
        rw [hL, hR,
          nRank_napp_first rest n2 hbr hb2 hcomp.2 hs2 ⟨e.1, hrest2⟩ hrest1]

/-- The second block of the union rank: an entry the first body does not claim
ranks past the whole first block -- the first body's bound plus its
second-body rank, `nRank_cons_rest` iterated with the offsets reassociated
into `nBound n1`. -/
theorem nRank_napp_rest : ∀ (n1 n2 : Node), bindsb n1 = false →
    bindsb n2 = false → nSubfree n1 = true → nSubfree n2 = true →
    ∀ (e : Entries (napp n1 n2)), ¬ denotes n1 e.1 → ∀ (h2 : denotes n2 e.1),
      nRank (napp n1 n2) e = nBound n1 + nRank n2 ⟨e.1, h2⟩
  | .nil, n2, _, _, _, _, e, _, h2 => by
      have hz : nBound Node.nil = 0 := by simp only [nBound]
      show nRank n2 ⟨e.1, e.2⟩ = nBound Node.nil + nRank n2 ⟨e.1, h2⟩
      rw [hz, zero_add]
  | .cons m rest, n2, hb1, hb2, hs1, hs2, e, h1, h2 => by
      have hbcomp : freeAmpb m = false ∧ bindsb rest = false := by
        rw [bindsb, Bool.or_eq_false_iff] at hb1
        exact hb1
      have hbm : bindsb (nsingle m) = false := by
        simp only [nsingle, bindsb, Bool.or_false]
        exact hbcomp.1
      have hbr : bindsb rest = false := hbcomp.2
      have hcomp : mSubfree m = true ∧ nSubfree rest = true := by
        simpa only [nSubfree, Bool.and_eq_true] using hs1
      have hsfr : subfreeb rest = true := nSubfree_subfreeb rest hcomp.2
      have hban : bindsb (napp rest n2) = false := by
        rw [bindsb_napp, hbr, hb2]
        rfl
      have hbc : bindsb (Node.cons m (napp rest n2)) = false := by
        rw [bindsb, Bool.or_eq_false_iff]
        exact ⟨hbcomp.1, hban⟩
      have hA : ¬ denotes (nsingle m) e.1 := fun hA =>
        h1 ((denotes_napp_iff (nsingle m) rest hbm hbr hsfr e.1).mpr (Or.inl hA))
      have hnr : ¬ denotes rest e.1 := fun hR =>
        h1 ((denotes_napp_iff (nsingle m) rest hbm hbr hsfr e.1).mpr (Or.inr hR))
      have hrest2 : denotes (napp rest n2) e.1 :=
        ((denotes_napp_iff (nsingle m) (napp rest n2) hbm hban
          (subfreeb_napp rest n2 hsfr (nSubfree_subfreeb n2 hs2)) e.1).mp
            e.2).resolve_left hA
      have hL : nRank (napp (.cons m rest) n2) e
          = mBound m + nRank (napp rest n2) ⟨e.1, hrest2⟩ :=
        nRank_cons_rest hbc e hA hrest2
      rw [hL, nRank_napp_rest rest n2 hbr hb2 hcomp.2 hs2 ⟨e.1, hrest2⟩ hnr h2,
        nBound_cons_nb hb1, add_assoc]

/-- Restricting the recursive order to any predicate keeps it a well order --
the instance the unclaimed remainder's order type reads. -/
theorem entryRecLt_subrel_isWellOrder (n : Node) (h : nSubfree n = true)
    (p : Entries n → Prop) : IsWellOrder (Subtype p) (Subrel (entryRecLt n) p) :=
  haveI := entryRecLt_isWellOrder n h
  inferInstance

/-- The unclaimed remainder's enumeration: the second body's entries the first
body does not claim, in the second body's own recursive order. Read on the
subtraction-free skeleton (junk `0` off it), like `entryRecType`. -/
noncomputable def entryRecRemType (n1 n2 : Node) : Ordinal :=
  if h : nSubfree n2 = true then
    @Ordinal.type _ (Subrel (entryRecLt n2) (fun e2 : Entries n2 => ¬ denotes n1 e2.1))
      (entryRecLt_subrel_isWellOrder n2 h _)
  else 0

theorem entryRecRemType_def (n1 n2 : Node) (h : nSubfree n2 = true) :
    entryRecRemType n1 n2
      = @Ordinal.type _
          (Subrel (entryRecLt n2) (fun e2 : Entries n2 => ¬ denotes n1 e2.1))
          (entryRecLt_subrel_isWellOrder n2 h _) :=
  dif_pos h

open Classical in
/-- Union first-owner pieces: route an entry of `napp n1 n2` to the first body
when it claims the spelling, else to the second body's unclaimed remainder.
Ownership is a function of the spelling (the `dif`), so the map is injective;
unlike `unionReinterp` the second component carries its unclaimed-ness, which
is what makes the map onto. -/
noncomputable def unionRecPieces (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hsf2 : subfreeb n2 = true)
    (e : Entries (napp n1 n2)) :
    Entries n1 ⊕ {e2 : Entries n2 // ¬ denotes n1 e2.1} :=
  if h : denotes n1 e.1 then Sum.inl ⟨e.1, h⟩
  else Sum.inr ⟨⟨e.1,
    ((denotes_napp_iff n1 n2 hb1 hb2 hsf2 e.1).mp e.2).resolve_left h⟩, h⟩

open Classical in
/-- The recursive union enumeration is the appended enumeration: first body,
then the unclaimed remainder, as a lex sum -- the recursive analogue of
`unionSumIso`, with the block law supplying the order agreement in place of
the body-major `(owner, spelling)` bookkeeping. -/
noncomputable def unionRecIso (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hs1 : nSubfree n1 = true)
    (hs2 : nSubfree n2 = true) :
    entryRecLt (napp n1 n2) ≃r
      Sum.Lex (entryRecLt n1)
        (Subrel (entryRecLt n2) (fun e2 : Entries n2 => ¬ denotes n1 e2.1)) where
  toEquiv := Equiv.ofBijective
    (unionRecPieces n1 n2 hb1 hb2 (nSubfree_subfreeb n2 hs2)) (by
    constructor
    · intro x y hxy
      simp only [unionRecPieces] at hxy
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
    · rintro (⟨t, ht⟩ | ⟨⟨t, ht2⟩, ht1⟩)
      · exact ⟨⟨t, (denotes_napp_iff n1 n2 hb1 hb2
          (nSubfree_subfreeb n2 hs2) t).mpr (Or.inl ht)⟩, dif_pos ht⟩
      · refine ⟨⟨t, (denotes_napp_iff n1 n2 hb1 hb2
          (nSubfree_subfreeb n2 hs2) t).mpr (Or.inr ht2)⟩, ?_⟩
        simp only [unionRecPieces]
        rw [dif_neg ht1])
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply, unionRecPieces]
    by_cases hx : denotes n1 x.1 <;> by_cases hy : denotes n1 y.1
    · rw [dif_pos hx, dif_pos hy, Sum.lex_inl_inl]
      show (nRank n1 ⟨x.1, hx⟩ < nRank n1 ⟨y.1, hy⟩)
        ↔ (nRank (napp n1 n2) x < nRank (napp n1 n2) y)
      rw [nRank_napp_first n1 n2 hb1 hb2 hs1 hs2 x hx,
        nRank_napp_first n1 n2 hb1 hb2 hs1 hs2 y hy]
    · rw [dif_pos hx, dif_neg hy]
      refine iff_of_true (Sum.Lex.sep _ _) ?_
      have hy2 : denotes n2 y.1 :=
        ((denotes_napp_iff n1 n2 hb1 hb2
          (nSubfree_subfreeb n2 hs2) y.1).mp y.2).resolve_left hy
      show nRank (napp n1 n2) x < nRank (napp n1 n2) y
      rw [nRank_napp_first n1 n2 hb1 hb2 hs1 hs2 x hx,
        nRank_napp_rest n1 n2 hb1 hb2 hs1 hs2 y hy hy2]
      exact (entryRank_lt_entryBound n1 hs1 ⟨x.1, hx⟩).trans_le le_self_add
    · rw [dif_neg hx, dif_pos hy]
      refine iff_of_false Sum.lex_inr_inl ?_
      have hx2 : denotes n2 x.1 :=
        ((denotes_napp_iff n1 n2 hb1 hb2
          (nSubfree_subfreeb n2 hs2) x.1).mp x.2).resolve_left hx
      show ¬ (nRank (napp n1 n2) x < nRank (napp n1 n2) y)
      rw [nRank_napp_rest n1 n2 hb1 hb2 hs1 hs2 x hx hx2,
        nRank_napp_first n1 n2 hb1 hb2 hs1 hs2 y hy]
      exact not_lt.2
        ((entryRank_lt_entryBound n1 hs1 ⟨y.1, hy⟩).trans_le le_self_add).le
    · rw [dif_neg hx, dif_neg hy, Sum.lex_inr_inr]
      have hx2 : denotes n2 x.1 :=
        ((denotes_napp_iff n1 n2 hb1 hb2
          (nSubfree_subfreeb n2 hs2) x.1).mp x.2).resolve_left hx
      have hy2 : denotes n2 y.1 :=
        ((denotes_napp_iff n1 n2 hb1 hb2
          (nSubfree_subfreeb n2 hs2) y.1).mp y.2).resolve_left hy
      show (nRank n2 ⟨x.1, hx2⟩ < nRank n2 ⟨y.1, hy2⟩)
        ↔ (nRank (napp n1 n2) x < nRank (napp n1 n2) y)
      rw [nRank_napp_rest n1 n2 hb1 hb2 hs1 hs2 x hx hx2,
        nRank_napp_rest n1 n2 hb1 hb2 hs1 hs2 y hy hy2]
      exact (add_lt_add_iff_left (nBound n1)).symm

/-- The union law on the recursive enumeration: the union enumerates as the
ordinal sum of the first body and the second body's unclaimed remainder --
the doc's append rule with the skip rule priced in, the migration replacement
for `unionLt_type`. -/
theorem entryRecType_napp (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hs1 : nSubfree n1 = true)
    (hs2 : nSubfree n2 = true) :
    entryRecType (napp n1 n2) = entryRecType n1 + entryRecRemType n1 n2 := by
  have hsub : nSubfree (napp n1 n2) = true := nSubfree_napp n1 n2 hs1 hs2
  haveI := entryRecLt_isWellOrder n1 hs1
  haveI := entryRecLt_isWellOrder n2 hs2
  haveI := entryRecLt_isWellOrder (napp n1 n2) hsub
  rw [entryRecType_def (napp n1 n2) hsub, entryRecType_def n1 hs1,
    entryRecRemType_def n1 n2 hs2]
  exact (Ordinal.type_eq.mpr ⟨unionRecIso n1 n2 hb1 hb2 hs1 hs2⟩).trans
    (type_sum_lex (entryRecLt n1)
      (Subrel (entryRecLt n2) (fun e2 : Entries n2 => ¬ denotes n1 e2.1)))

/-- With disjoint bodies nothing is claimed: the remainder is the whole second
body. -/
theorem entryRecRemType_disjoint (n1 n2 : Node) (hs2 : nSubfree n2 = true)
    (hdisj : ∀ s, denotes n1 s → ¬ denotes n2 s) :
    entryRecRemType n1 n2 = entryRecType n2 := by
  haveI := entryRecLt_isWellOrder n2 hs2
  rw [entryRecRemType_def n1 n2 hs2, entryRecType_def n2 hs2]
  exact Ordinal.type_eq.mpr
    ⟨⟨Equiv.subtypeUnivEquiv (fun e2 h1 => hdisj e2.1 h1 e2.2), Iff.rfl⟩⟩

/-- The disjoint corollary: nothing to skip, so the union enumerates at
exactly the sum of the body enumerations -- the migration replacement for
`unionLt_type_disjoint`. -/
theorem entryRecType_napp_disjoint (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hs1 : nSubfree n1 = true)
    (hs2 : nSubfree n2 = true)
    (hdisj : ∀ s, denotes n1 s → ¬ denotes n2 s) :
    entryRecType (napp n1 n2) = entryRecType n1 + entryRecType n2 := by
  rw [entryRecType_napp n1 n2 hb1 hb2 hs1 hs2,
    entryRecRemType_disjoint n1 n2 hs2 hdisj]

/- ---------------------------------------------------------------- -/
/- STEP 5d: closure enumeration types -- the Phase-E analogue over  -/
/- the recursive order: predecessors live inside one finite stage,  -/
/- so finite stages cap `entryRecType` at omega.                    -/
/- See RecOrder.design.md 5.                                        -/
/- ---------------------------------------------------------------- -/

/-- On a binder node the body-recursive entry rank is the closure rank: the
union-spine recursion's binder branch, read at the top level. -/
theorem entryRank_binder : ∀ (n : Node), bindsb n = true →
    ∀ (e : Entries n), entryRank n e = cRank n e
  | .nil, _, e => absurd e.2 (denotes_nnil e.1)
  | .cons m rest, hb, e => by
      show nRank (.cons m rest) e = cRank (.cons m rest) e
      simp only [nRank, hb, if_true]

/-- Braced closures keep their enumeration: a fold wrapped around a binder
body wears the body's own entries at the body's own recursive rank (the
`mRank (.fold inner)` binder branch routes through `foldBinderReinterp`), so
the enumeration is unchanged. -/
theorem entryRecType_fold_binder (n : Node) (hb : bindsb n = true)
    (hsub : nSubfree n = true) :
    entryRecType (nsingle (.fold n)) = entryRecType n := by
  have hfsub : nSubfree (nsingle (.fold n)) = true := by
    simp [nsingle, nSubfree, mSubfree, hsub]
  have hbf : bindsb (nsingle (.fold n)) = false := by
    simp [nsingle, bindsb, freeAmpb]
  have hrank : ∀ e : Entries (nsingle (.fold n)),
      entryRank (nsingle (.fold n)) e = entryRank n (foldBinderReinterp n hb e) := by
    intro e
    rw [entryRank_binder n hb]
    show nRank (Node.cons (.fold n) Node.nil) e = cRank n (foldBinderReinterp n hb e)
    rw [nRank_cons_first hbf e e.2]
    simp only [mRank, dif_pos hb]
  haveI := entryRecLt_isWellOrder (nsingle (.fold n)) hfsub
  haveI := entryRecLt_isWellOrder n hsub
  rw [entryRecType_def _ hfsub, entryRecType_def n hsub]
  refine Ordinal.type_eq.mpr ⟨⟨Equiv.ofBijective (foldBinderReinterp n hb)
    ⟨foldBinderReinterp_injective n hb, ?_⟩, ?_⟩⟩
  · intro e
    exact ⟨⟨e.1, (denotes_fold_binder n hb e.1).mpr e.2⟩, Subtype.ext rfl⟩
  · intro x y
    show entryRank n (foldBinderReinterp n hb x) < entryRank n (foldBinderReinterp n hb y)
      ↔ entryRank (nsingle (.fold n)) x < entryRank (nsingle (.fold n)) y
    rw [hrank x, hrank y]

/-- Below a fixed entry, the recursive order draws from one finite stage: a
predecessor's closure rank is smaller, so by the contrapositive of stage-major
disjointness (`cRank_lt_of_firstStage_lt`) it appears no later, and stage
monotonicity puts it inside the fixed entry's own first stage -- the
`entryLt_finite_predecessors` argument with the rank comparison in place of
the address comparison. -/
theorem entryRecLt_finite_predecessors (n : Node) (hb : bindsb n = true)
    (hsub : nSubfree n = true) (hfin : ∀ k, {s | stage n k s}.Finite)
    (x : Entries n) : {y | entryRecLt n y x}.Finite := by
  have hstage : ∀ e : Entries n, stage n (firstStage n e.1) e.1 := fun e =>
    firstStage_stage n e.1 ((ndenote_binder n (fun _ => False) e.1 hb).mp e.2)
  have hpool : {y | entryRecLt n y x} ⊆
      Subtype.val ⁻¹' {s | stage n (firstStage n x.1) s} := by
    intro y hy
    have hlt : cRank n y < cRank n x := by
      have h0 : entryRank n y < entryRank n x := hy
      rw [entryRank_binder n hb y, entryRank_binder n hb x] at h0
      exact h0
    have hle : firstStage n y.1 ≤ firstStage n x.1 := by
      by_contra hgt
      rw [not_le] at hgt
      exact lt_asymm
        (cRank_lt_of_firstStage_lt n hsub (hstage x) (hstage y) hgt) hlt
    exact stage_mono_le n _ _ y.1 hle (hstage y)
  exact ((hfin _).preimage Subtype.val_injective.injOn).subset hpool

/-- Phase E on the recursive enumeration: a binder whose stages are all finite
enumerates its entries within the one limit -- `entryRecType` at most `ω`, the
`entryLt_type_le_omega0` claim transported to the body-recursive order. -/
theorem entryRecType_le_omega0 (n : Node) (hb : bindsb n = true)
    (hsub : nSubfree n = true) (hfin : ∀ k, {s | stage n k s}.Finite) :
    entryRecType n ≤ ω := by
  haveI := entryRecLt_isWellOrder n hsub
  rw [entryRecType_def n hsub]
  exact type_le_omega0_of_finite_predecessors _
    (entryRecLt_finite_predecessors n hb hsub hfin)

/-- The exact version: a binder with finite stages and infinitely many entries
spends the limit on the nose -- the recursive-order face of
`entryLt_type_eq_omega0`. -/
theorem entryRecType_eq_omega0 (n : Node) (hb : bindsb n = true)
    (hsub : nSubfree n = true) (hfin : ∀ k, {s | stage n k s}.Finite)
    (hinf : {s | denotes n s}.Infinite) : entryRecType n = ω := by
  haveI := entryRecLt_isWellOrder n hsub
  haveI : Infinite (Entries n) := Set.infinite_coe_iff.2 hinf
  rw [entryRecType_def n hsub]
  exact type_eq_omega0_of_finite_predecessors _
    (entryRecLt_finite_predecessors n hb hsub hfin)

/-- The demotion row's universe is deeply subtraction-free: no subtraction
anywhere in `{{{}}, &C}`. -/
theorem unitClosure_nSubfree (lo hi : Code) :
    nSubfree (unitClosure lo hi) = true := by
  simp [unitClosure, nSubfree, mSubfree, fSubfree]

/-- The demotion row on the recursive enumeration: `{{{}}, &C}` enumerates at
exactly `ω` -- what the migrated rows read where they now read
`unitClosure_entriesType`. -/
theorem unitClosure_entryRecType (lo hi : Code) (h : lo ≤ hi) :
    entryRecType (unitClosure lo hi) = ω :=
  entryRecType_eq_omega0 _ (unitClosure_bindsb lo hi)
    (unitClosure_nSubfree lo hi) (unitClosure_stage_finite lo hi)
    (unitClosure_entries_infinite lo hi h)

end L1
