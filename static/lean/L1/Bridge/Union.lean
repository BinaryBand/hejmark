/- L1 bridge: unions on real syntax -- the body-major entries enumeration.

`docs/foundation/L1.md` (Union `,`): "append a universe's entries, in its
order, skipping any already present". This file mechanizes that enumeration
over the real syntax: for `napp n1 n2` the first body owns every spelling
it denotes (the doc's skip rule -- a duplicate never re-enters), the
enumeration is body-major (`unionLt`), and its order type is the ordinal
sum of the first body's enumeration and the second body's unclaimed
remainder (`unionLt_type`), collapsing to `entriesType n1 + entriesType n2`
when the bodies are disjoint (`unionLt_type_disjoint`) -- the union half of
the doc's "union alone gives omega plus a finite tail", with `type_sum_lex`
reading ordinal addition off the appended carrier.

Within a body the enumeration is the spelling order, the same sanctioned
approximation `Entries.lean`'s `entryLt` makes within a stage; the fully
body-recursive within-body order stays deferred (`docs/.TODO.md`).

The denotation inversion `denotes_napp_iff` carries the honest hypotheses:
both bodies non-binders (a binder operand enters by bracing it once more --
`braced`, the doc's own move for folding a closure) and the second body
subtraction-free (a subtraction in the second body would strip the first
body's faces; one in the first body acts before the append and is
harmless). -/
import L1.Bridge.Entries

namespace L1

open Ordinal

/- ---------------------------------------------------------------- -/
/- Order-type congruence for restricted orders.                      -/
/- ---------------------------------------------------------------- -/

/-- Restricting a well order to equivalent predicates gives the same order
type. -/
theorem type_subrel_congr {α : Type*} (r : α → α → Prop) [IsWellOrder α r]
    {p q : α → Prop} (h : ∀ x, p x ↔ q x) :
    Ordinal.type (Subrel r p) = Ordinal.type (Subrel r q) :=
  Ordinal.type_eq.mpr ⟨⟨Equiv.subtypeEquivRight h, Iff.rfl⟩⟩

/-- Denotationally equal terms wear their entries at the same type. -/
theorem entriesType_congr {m n : Node} (h : ∀ s, denotes m s ↔ denotes n s) :
    entriesType m = entriesType n :=
  type_subrel_congr _ h

/- ---------------------------------------------------------------- -/
/- Bracing: how a binder enters a union.                             -/
/- ---------------------------------------------------------------- -/

/-- Brace a binder once more: a non-binder wrapper wearing exactly the
closure -- the doc's "to fold a closure, brace it once more". -/
def braced (n : Node) : Node := nsingle (.fold n)

theorem braced_bindsb (n : Node) : bindsb (braced n) = false := rfl

theorem braced_subfreeb (n : Node) : subfreeb (braced n) = true := rfl

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

/- ---------------------------------------------------------------- -/
/- The body-major enumeration.                                       -/
/- ---------------------------------------------------------------- -/

open Classical in
/-- Body ownership, the doc's "skipping any already present": a spelling
the first body denotes is the first body's entry, whatever the second body
says. -/
noncomputable def ownerRank (n1 : Node) (s : Spelling) : ℕ :=
  if denotes n1 s then 0 else 1

/-- The body-major union order: the first body's entries first, then the
second body's unclaimed remainder, spelling order within a body. -/
def unionLt (n1 n2 : Node) : Entries (napp n1 n2) → Entries (napp n1 n2) → Prop :=
  fun a b => Prod.Lex (· < ·) (List.Shortlex (· < ·))
    (ownerRank n1 a.1, a.1) (ownerRank n1 b.1, b.1)

/-- Body-major addresses embed into the lex order on `(owner, spelling)`
pairs -- the union face of `Entries.lean`'s `entryAddrEmb`. -/
noncomputable def unionAddrEmb (n1 n2 : Node) :
    unionLt n1 n2 ↪r
      Prod.Lex ((· < ·) : ℕ → ℕ → Prop)
        (List.Shortlex ((· < ·) : Code → Code → Prop)) :=
  ⟨⟨fun a => (ownerRank n1 a.1, a.1), fun _ _ h => Subtype.ext (congrArg Prod.snd h)⟩,
    Iff.rfl⟩

instance (n1 n2 : Node) : IsWellOrder (Entries (napp n1 n2)) (unionLt n1 n2) :=
  (unionAddrEmb n1 n2).isWellOrder

open Classical in
/-- The body-major enumeration is the appended enumeration: first body,
then the unclaimed remainder, as a lex sum. -/
noncomputable def unionSumIso (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hsf2 : subfreeb n2 = true) :
    unionLt n1 n2 ≃r Sum.Lex (entrySpellLt n1)
      (Subrel (List.Shortlex ((· < ·) : Code → Code → Prop))
        (fun s => denotes n2 s ∧ ¬ denotes n1 s)) where
  toEquiv := Equiv.ofBijective (fun e =>
    if h : denotes n1 e.1 then Sum.inl ⟨e.1, h⟩
    else Sum.inr ⟨e.1,
      ⟨((denotes_napp_iff n1 n2 hb1 hb2 hsf2 e.1).mp e.2).resolve_left h, h⟩⟩) (by
    constructor
    · intro x y hxy
      dsimp only at hxy
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
    · rintro (⟨t, ht⟩ | ⟨t, ht2, ht1⟩)
      · exact ⟨⟨t, (denotes_napp_iff n1 n2 hb1 hb2 hsf2 t).mpr (Or.inl ht)⟩,
          dif_pos ht⟩
      · exact ⟨⟨t, (denotes_napp_iff n1 n2 hb1 hb2 hsf2 t).mpr (Or.inr ht2)⟩,
          dif_neg ht1⟩)
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply, unionLt]
    by_cases hx : denotes n1 x.1 <;> by_cases hy : denotes n1 y.1
    · rw [dif_pos hx, dif_pos hy, Sum.lex_inl_inl, Prod.lex_def]
      simp [ownerRank, if_pos hx, if_pos hy, entrySpellLt, subrel_val]
    · rw [dif_pos hx, dif_neg hy]
      refine iff_of_true (Sum.Lex.sep _ _) (Prod.lex_def.mpr (Or.inl ?_))
      simp only [ownerRank, if_pos hx, if_neg hy]
      omega
    · rw [dif_neg hx, dif_pos hy]
      refine iff_of_false Sum.lex_inr_inl ?_
      intro h
      rcases Prod.lex_def.mp h with hlt | ⟨heq, -⟩
      · simp only [ownerRank, if_neg hx, if_pos hy] at hlt; omega
      · simp only [ownerRank, if_neg hx, if_pos hy] at heq; omega
    · rw [dif_neg hx, dif_neg hy, Sum.lex_inr_inr, Prod.lex_def]
      simp [ownerRank, if_neg hx, if_neg hy, subrel_val]

/-- Headline: the body-major union enumeration is the ordinal sum of the
first body and the second body's unclaimed remainder -- the doc's append
rule with the skip rule priced in. -/
theorem unionLt_type (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hsf2 : subfreeb n2 = true) :
    Ordinal.type (unionLt n1 n2) = entriesType n1
      + Ordinal.type (Subrel (List.Shortlex ((· < ·) : Code → Code → Prop))
          (fun s => denotes n2 s ∧ ¬ denotes n1 s)) := by
  rw [Ordinal.type_eq.mpr ⟨unionSumIso n1 n2 hb1 hb2 hsf2⟩, type_sum_lex]
  rfl

/-- The disjoint corollary: nothing to skip, so the union enumerates at
exactly the sum of the body enumerations. -/
theorem unionLt_type_disjoint (n1 n2 : Node) (hb1 : bindsb n1 = false)
    (hb2 : bindsb n2 = false) (hsf2 : subfreeb n2 = true)
    (hdisj : ∀ s, denotes n1 s → ¬ denotes n2 s) :
    Ordinal.type (unionLt n1 n2) = entriesType n1 + entriesType n2 := by
  rw [unionLt_type n1 n2 hb1 hb2 hsf2,
    type_subrel_congr (List.Shortlex ((· < ·) : Code → Code → Prop))
      (p := fun s => denotes n2 s ∧ ¬ denotes n1 s) (q := fun s => denotes n2 s)
      (fun s => ⟨fun h => h.1, fun h => ⟨h, fun h1 => hdisj s h1 h⟩⟩)]
  rfl

end L1
