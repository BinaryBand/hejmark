/- L1 order axis, phase C: collision ownership -- the least `<value, face>` claim rule.

`docs/foundation/L1.md` (Positional value): "One rule settles every collision, within an entry and
across entries alike: a spelling is claimed by the least `<value, face>` address that spells it --
value first, face index to break the tie -- and every later claimant drops it, exactly as fold drops
a claimed spelling."

An **address** is a `<value, face>` pair: `value` is an ordinal (below ε₀ for a real universe, but
the collision rule needs only that ordinals are well-ordered), `face` a natural index into that
entry's faces. Addresses are ordered lexicographically -- value dominates, face breaks the tie --
which is `Ordinal ×ₗ Nat`. A **claim configuration** is a map `spell : Address → S` sending each
address to the spelling that face writes; a *collision* is two distinct addresses spelling the same
`s`.

The rule is a minimization over a well-order. `Ordinal ×ₗ Nat` is a well-order (both factors are, and
`Prod.Lex` of well-orders is a well-order), so for any spelling the set of addresses that write it,
being nonempty, has a least element under `<value, face>`. The headline `collision_settled` cashes
"one rule settles every collision": every address's spelling has a *unique* survivor -- the lex-least
claimant owns it, and (by `non_owner_drops`) every other claimant sits strictly above and drops.
Uniqueness is what makes ownership a well-defined function of the spelling, so "canonical stays index
0" renumbering is coherent: no spelling is owned twice.

The three concrete facts (`value_dominates`, `face_breaks_tie`, and the cross-axis example) check
that this lex order resolves exactly the doc's three documented collisions -- across entries the
lower value keeps it (`{a,ab}{c,bc}`), within an entry the lower face keeps it (Z² `{{{},0}}{{{},0}}`),
and cross-axis the lower value keeps it even against a lower face index (`{{{},0}}{0,00}`, where the
value-0 entry keeps `00` though it wears the higher face index).

Independent of the membership axis, exactly like `L1/Order.lean` and `L1/Positional.lean`; `Code`
stays `Nat` everywhere else. -/
import Mathlib.Data.Prod.Lex
import Mathlib.SetTheory.Ordinal.Basic
import Mathlib.Order.WellFounded

namespace L1

/-- An address: a `<value, face>` pair, ordered lexicographically. `value` (an ordinal) dominates;
`face` (a natural) breaks the tie -- exactly the doc's `<value, face>` claim address. -/
abbrev Address := Ordinal ×ₗ Nat

/-- The collision rule as a survivor predicate: `a` owns its spelling iff it is the lex-least address
that writes `spell a`. Every strictly greater claimant of the same spelling drops (`non_owner_drops`). -/
def Survives {S : Type*} (spell : Address → S) (a : Address) : Prop :=
  ∀ a', spell a' = spell a → a ≤ a'

/- ---------------------------------------------------------------- -/
/- Collision is settled: a unique least claimant owns every spelling. -/
/- ---------------------------------------------------------------- -/

/-- Collision ownership, phase C: every address's spelling has a **unique** survivor. The lex-least
`<value, face>` claimant owns the spelling; uniqueness makes ownership a well-defined function of the
spelling, so no spelling is claimed twice. This is the doc's "one rule settles every collision." -/
theorem collision_settled {S : Type*} (spell : Address → S) (a : Address) :
    ∃! o, Survives spell o ∧ spell o = spell a := by
  have wf : WellFounded ((· < ·) : Address → Address → Prop) := wellFounded_lt
  have hne : ({a' | spell a' = spell a} : Set Address).Nonempty := ⟨a, rfl⟩
  obtain ⟨o, ho_mem, ho_least⟩ :
      ∃ o ∈ ({a' | spell a' = spell a} : Set Address),
        ∀ x ∈ ({a' | spell a' = spell a} : Set Address), o ≤ x :=
    ⟨wf.min _ hne, wf.min_mem _ hne, fun _ hx => wf.min_le hx⟩
  have ho_spell : spell o = spell a := ho_mem
  refine ⟨o, ⟨fun a' ha' => ho_least a' (ha'.trans ho_spell), ho_spell⟩, ?_⟩
  rintro y ⟨hSy, hy⟩
  exact le_antisymm (hSy o (ho_spell.trans hy.symm)) (ho_least y hy)

/-- The drop: any claimant of an owned spelling other than the owner sits strictly above it, so it
loses the spelling -- "every later claimant drops it." -/
theorem non_owner_drops {S : Type*} (spell : Address → S) {a o : Address}
    (ho : Survives spell o) (hspell : spell a = spell o) (hne : a ≠ o) : o < a :=
  lt_of_le_of_ne (ho a hspell) (Ne.symm hne)

/- ---------------------------------------------------------------- -/
/- The lex order resolves the doc's three documented collisions.     -/
/- ---------------------------------------------------------------- -/

/-- Across entries, the lower value owns the collision regardless of face indices: value dominates.
Cashes `{a,ab}{c,bc}`, where `abc`'s claimant at value 1 beats the one at value 2. -/
theorem value_dominates {v w : Ordinal} (f g : Nat) (h : v < w) :
    (toLex (v, f) : Address) < toLex (w, g) :=
  Prod.Lex.toLex_lt_toLex.mpr (Or.inl h)

/-- Within one entry (same value), the lower face index owns: the face axis breaks the tie. Cashes
Z² `{{{},0}}{{{},0}}`, where `0` written by the left and right fill collide at one value and the
lower face survives. -/
theorem face_breaks_tie {v : Ordinal} {f g : Nat} (h : f < g) :
    (toLex (v, f) : Address) < toLex (v, g) :=
  Prod.Lex.toLex_lt_toLex.mpr (Or.inr ⟨rfl, h⟩)

/-- Cross-axis: a lower value with a *higher* face index still owns -- value dominates the face axis.
Cashes `{{{},0}}{0,00}`, where `00`'s claimants are `<0,1>` and `<1,0>` and the value-0 entry keeps
it though it wears the higher face index, losing its canonical face. -/
theorem value_over_face : (toLex ((0 : Ordinal), 1) : Address) < toLex ((1 : Ordinal), 0) :=
  value_dominates 1 0 zero_lt_one

end L1
