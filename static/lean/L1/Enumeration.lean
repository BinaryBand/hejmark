/- L1 order axis, phase E: first-appearance enumeration fits within one limit.

`docs/foundation/L1.md` (Closure `&`): entries of a closure are "ordered by first appearance --
stage-major, body order within a stage", with "one limit and no continuation past it: a body still
producing at omega is cut there". This file mechanizes the order-theoretic content of that
enumeration rule: the stage-major order over omega-many finite stages is a well order of type at
most omega -- the enumeration always fits within the one limit -- and of type exactly omega when
new entries keep appearing (the numerals row `{0, {1..9, &{0..9}}}`, where first-appearance order
is value order).

Like the other order-axis phases this is an abstract mechanization: stages are modeled by their
new-entry counts (`f : Nat -> Nat`) and the enumeration by the lexicographic order on
`(stage, in-stage index)` addresses, not by an enumeration of the real syntax (`Universe.entries`
over `Syntax.lean` remains the deferred integration; `Settling.lean`'s stage semantics is where the
real stages live). The engine is a general fact worth stating on its own: a well order in which
every element has finitely many predecessors has type at most omega
(`type_le_omega0_of_finite_predecessors`) -- "finitely many predecessors" is exactly what
stage-major order over finite stages guarantees, and exactly what fails past the first limit. -/
import Mathlib.Tactic
import Mathlib.SetTheory.Ordinal.Arithmetic

namespace L1

open Ordinal

universe u

variable {α : Type u}

/- ---------------------------------------------------------------- -/
/- The engine: finitely many predecessors everywhere caps the type   -/
/- at omega.                                                         -/
/- ---------------------------------------------------------------- -/

/-- A well order in which every element has finitely many predecessors fits within one limit: its
order type is at most `ω`. (Past `ω` there is an element with `ω`-many predecessors, namely the one
`typein` sends to `ω`.) -/
theorem type_le_omega0_of_finite_predecessors (r : α → α → Prop) [IsWellOrder α r]
    (h : ∀ x, {y | r y x}.Finite) : Ordinal.type r ≤ ω := by
  by_contra hlt
  rw [not_le] at hlt
  obtain ⟨x, hx⟩ := typein_surj r hlt
  haveI : Finite (Subtype (r · x)) := (h x).to_subtype
  haveI : Fintype (Subtype (r · x)) := Fintype.ofFinite _
  have hcard : typein r x = (Fintype.card (Subtype (r · x)) : Ordinal) := by
    rw [← type_subrel]
    exact type_fintype _
  rw [hx] at hcard
  exact (natCast_lt_omega0 _).ne' hcard

/-- The exact version: an infinite well order with finitely many predecessors everywhere has type
exactly `ω`. -/
theorem type_eq_omega0_of_finite_predecessors (r : α → α → Prop) [IsWellOrder α r] [Infinite α]
    (h : ∀ x, {y | r y x}.Finite) : Ordinal.type r = ω := by
  refine le_antisymm (type_le_omega0_of_finite_predecessors r h) ?_
  by_contra hlt
  rw [not_le] at hlt
  obtain ⟨n, hn⟩ := lt_omega0.1 hlt
  have hcard : Cardinal.mk α = n := by
    rw [← card_type r, hn]
    simp
  haveI : Finite α :=
    Cardinal.mk_lt_aleph0_iff.1 (by rw [hcard]; exact Cardinal.natCast_lt_aleph0)
  exact not_finite α

/- ---------------------------------------------------------------- -/
/- The instantiation: stage-major first-appearance addresses.        -/
/- ---------------------------------------------------------------- -/

/-- First-appearance addresses for stage sizes `f`: stage `k` contributes `f k` new entries,
indexed `0, …, f k - 1` in body order. -/
def stageAddr (f : ℕ → ℕ) : ℕ × ℕ → Prop := fun p => p.2 < f p.1

/-- The first-appearance order: stage-major, body order within a stage -- lexicographic on
`(stage, in-stage index)`. -/
def stageMajor (f : ℕ → ℕ) : Subtype (stageAddr f) → Subtype (stageAddr f) → Prop :=
  Subrel (Prod.Lex (· < ·) (· < ·)) (stageAddr f)

instance (f : ℕ → ℕ) : IsWellOrder _ (stageMajor f) :=
  inferInstanceAs (IsWellOrder _ (Subrel _ _))

/-- Every address has finitely many stage-major predecessors: earlier stages are finitely many and
each contributes finitely many entries -- the structural reason the enumeration never leaves
`ω`. -/
theorem stageMajor_finite_predecessors (f : ℕ → ℕ) (x : Subtype (stageAddr f)) :
    {y | stageMajor f y x}.Finite := by
  obtain ⟨⟨k, i⟩, hx⟩ := x
  have hsub : {y : Subtype (stageAddr f) | stageMajor f y ⟨(k, i), hx⟩} ⊆
      Subtype.val ⁻¹' (Set.Iic k ×ˢ Set.Iio (max ((Finset.range (k + 1)).sup f) i)) := by
    rintro ⟨⟨a, b⟩, hab⟩ hy
    simp [stageMajor, subrel_val, Prod.lex_def] at hy
    have hb : b < f a := hab
    simp only [Set.mem_preimage, Set.mem_prod, Set.mem_Iic, Set.mem_Iio]
    rcases hy with h1 | ⟨h1, h2⟩
    · have hfa : f a ≤ (Finset.range (k + 1)).sup f :=
        Finset.le_sup (Finset.mem_range.2 (by omega))
      exact ⟨Nat.le_of_lt h1, lt_of_lt_of_le (lt_of_lt_of_le hb hfa) (le_max_left _ _)⟩
    · exact ⟨le_of_eq h1, lt_of_lt_of_le h2 (le_max_right _ _)⟩
  exact (((Set.finite_Iic k).prod (Set.finite_Iio _)).preimage
    Subtype.val_injective.injOn).subset hsub

/-- Headline: first-appearance enumeration fits within the one limit -- stage-major order over
`ω`-many finite stages has order type at most `ω`. This is "one limit and no continuation past
it" as an order-type bound. -/
theorem stageMajor_type_le_omega0 (f : ℕ → ℕ) : Ordinal.type (stageMajor f) ≤ ω :=
  type_le_omega0_of_finite_predecessors _ (stageMajor_finite_predecessors f)

/-- When new entries appear at cofinally many stages the enumeration spends the limit exactly:
order type `ω` on the nose -- the numerals row, where first-appearance order is value order. -/
theorem stageMajor_type_eq_omega0 (f : ℕ → ℕ) (hinf : ∀ k, ∃ j, k ≤ j ∧ 0 < f j) :
    Ordinal.type (stageMajor f) = ω := by
  have hset : {p : ℕ × ℕ | p.2 < f p.1}.Infinite := by
    intro hfin
    have himg : (Prod.fst '' {p : ℕ × ℕ | p.2 < f p.1}).Finite := hfin.image _
    obtain ⟨B, hB⟩ := himg.bddAbove
    obtain ⟨j, hjB, hj⟩ := hinf (B + 1)
    have hmem : j ∈ Prod.fst '' {p : ℕ × ℕ | p.2 < f p.1} := ⟨(j, 0), hj, rfl⟩
    have := hB hmem
    omega
  haveI : Infinite (Subtype (stageAddr f)) := Set.infinite_coe_iff.2 hset
  exact type_eq_omega0_of_finite_predecessors _ (stageMajor_finite_predecessors f)

end L1
