/- L1 bridge: unions on real syntax -- the body-major entries enumeration.

`docs/foundation/L1.md` (Union `,`): "append a universe's entries, in its
order, skipping any already present". This file supplies the denotation
inversion and the bracing move that the union enumeration is built on; the
enumeration itself and its order type -- the ordinal sum of the first body
and the second body's unclaimed remainder -- now live in `RecOrder.lean`'s
body-recursive order (`entryRecType_napp`, `entryRecType_napp_disjoint`),
which recurses into each body rather than ordering it by raw shortlex.

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

end L1
