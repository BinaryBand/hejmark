/- L1 order axis, phase D: bounded transfinitude -- the ordinal ceiling.

`docs/foundation/L1.md` ("Bounded transfinitude"): order types are the ordinals below epsilon_0,
closed under every constructor and never reaching the bound, and the bound is stratified: below
closure the floor lives below omega^omega, linear closure stays below omega^omega as well, nonlinear
closure squares its stage type each pass and spends the raised bound (the binary-tree row's closure
is the first universe of type exactly omega^omega), and no finite expression reaches epsilon_0,
because a closure of stages below the bound has its limit at omega^(alpha * omega) for an alpha
already under it.

Like the other order-axis phases this is an abstract mechanization: order types are modeled by the
ordinal calculus the doc's argument actually runs on -- inductive sets of reachable order types,
closed under the constructors' ordinal effects -- rather than by an enumeration of the real syntax
(`Universe.entries` over `Syntax.lean` remains the deferred integration). Each doc sentence maps to
a theorem here:

- "union alone gives omega plus a finite tail; product climbs": `two_blocks_type` is the
  `{b,c}{a..}` row (omega * 2) and `seam_blocks_type` the collision-free reading of the
  `{b}{a..}{b}{a..}` row (omega ^ 2), both read off `Ordinal.type_prod_lex` with the left factor as
  the most-significant digit -- the positional-value reading.
- "n * omega = omega collapses any digit placed on the left": `left_digit_collapses`, with
  `mul_order_load_bearing` recording that the same digit on the right stands, so the order of
  multiplication in Cantor normal form is load-bearing.
- "Below closure the floor lives below omega^omega": `floorType_lt_omega0_opow_omega0`, over the
  inductive calculus `FloorType` (finite universes, the final segment's omega, union sums, product
  products).
- "Linear closure ... the limit is at most u * omega": `linear_closure_le`, kept under omega^omega
  by `linear_closure_lt_omega0_opow_omega0`.
- "Nonlinear closure ... squares its stage type each pass ... type exactly omega^omega":
  `nonlinear_closure_sup` -- the supremum of the squared stage types omega^(2^n) is omega^omega on
  the nose, spent and not overshot.
- "a closure of stages below epsilon_0 stays below it ... the limit sits at omega^(alpha * omega)":
  `stages_le_climb` bounds any stage sequence dominated by omega^(alpha * k), and the headline
  `l1Type_lt_epsilon0` closes the loop: the full calculus `L1Type` -- naturals, omega, sums,
  products, and the closure limit omega^(alpha * omega) -- never reaches epsilon_0. -/
import Mathlib.Tactic
import Mathlib.SetTheory.Ordinal.Principal
import Mathlib.SetTheory.Ordinal.Veblen

namespace L1

open Ordinal

universe u

/- ---------------------------------------------------------------- -/
/- Stratum 1: below closure the floor lives below omega^omega.       -/
/- ---------------------------------------------------------------- -/

/-- The order types reachable without closure: finite universes, the final segment's `ω`, union
(ordinal sum: the right operand's entries appended after the left's), and product (ordinal product:
the left factor most significant). Subtraction and fold only shrink, so they add no clause. -/
inductive FloorType : Ordinal → Prop
  | nat (n : ℕ) : FloorType n
  | omega : FloorType ω
  | add {a b : Ordinal} : FloorType a → FloorType b → FloorType (a + b)
  | mul {a b : Ordinal} : FloorType a → FloorType b → FloorType (a * b)

theorem omega0_lt_omega0_opow_omega0 : ω < ω ^ ω := by
  conv_lhs => rw [← opow_one ω]
  exact (opow_lt_opow_iff_right one_lt_omega0).2 one_lt_omega0

theorem isPrincipal_mul_omega0_opow_omega0 : IsPrincipal (· * ·) (ω ^ ω) := by
  have h := isPrincipal_mul_omega0_opow_opow 1
  rwa [opow_one] at h

/-- Stratum 1: every closure-free order type sits strictly below `ω ^ ω`. -/
theorem floorType_lt_omega0_opow_omega0 {a : Ordinal} (h : FloorType a) : a < ω ^ ω := by
  induction h with
  | nat n => exact (natCast_lt_omega0 n).trans omega0_lt_omega0_opow_omega0
  | omega => exact omega0_lt_omega0_opow_omega0
  | add _ _ iha ihb => exact isPrincipal_add_omega0_opow ω iha ihb
  | mul _ _ iha ihb => exact isPrincipal_mul_omega0_opow_omega0 iha ihb

/- ---------------------------------------------------------------- -/
/- The doc's two product rows, read off the lex product.             -/
/- ---------------------------------------------------------------- -/

/-- `{b,c}{a..}`: a finite most-significant digit over an `ω` block -- order type `ω * 2`. -/
theorem two_blocks_type :
    Ordinal.type (Prod.Lex ((· < ·) : Fin 2 → Fin 2 → Prop) ((· < ·) : ℕ → ℕ → Prop)) = ω * 2 := by
  rw [type_prod_lex]
  rw [show Ordinal.type ((· < ·) : ℕ → ℕ → Prop) = ω from type_nat_lt]
  rw [show Ordinal.type ((· < ·) : Fin 2 → Fin 2 → Prop) = 2 from type_fin 2]

/-- `{b}{a..}{b}{a..}` with the seams kept apart: `ω`-many `ω` blocks -- order type `ω ^ 2`.
(Whether collision preserves this type is phase G, `Collapse.lean`.) -/
theorem seam_blocks_type :
    Ordinal.type (Prod.Lex ((· < ·) : ℕ → ℕ → Prop) ((· < ·) : ℕ → ℕ → Prop)) = ω ^ (2 : Ordinal) := by
  rw [type_prod_lex]
  rw [show Ordinal.type ((· < ·) : ℕ → ℕ → Prop) = ω from type_nat_lt]
  rw [show (2 : Ordinal) = 1 + 1 by norm_num, opow_add, opow_one]

/- ---------------------------------------------------------------- -/
/- Cantor normal form: the order of multiplication is load-bearing.  -/
/- ---------------------------------------------------------------- -/

/-- "`n * ω = ω` collapses any digit placed on the left." -/
theorem left_digit_collapses {n : ℕ} (hn : 0 < n) : (n : Ordinal) * ω = ω :=
  mul_omega0 (by exact_mod_cast hn) (natCast_lt_omega0 n)

/-- The same digit on the right stands: with an infinite factor the order of multiplication is
load-bearing, unlike the finite case where it is invisible (`Positional.lean`). -/
theorem mul_order_load_bearing : (2 : Ordinal) * ω = ω ∧ ω < ω * 2 := by
  constructor
  · have h2 : ((2 : ℕ) : Ordinal) * ω = ω := mul_omega0 (by norm_num) (natCast_lt_omega0 2)
    simpa using h2
  · conv_lhs => rw [← mul_one ω]
    exact mul_lt_mul_of_pos_left one_lt_two omega0_pos

/- ---------------------------------------------------------------- -/
/- Stratum 2: linear closure stays below omega^omega.                -/
/- ---------------------------------------------------------------- -/

/-- Linear closure -- at most one `&` per product, its co-factors finite -- multiplies each stage by
a finite on the right, so every stage sits below `u * ω` for the base members' own bound `u`, and so
does the limit. -/
theorem linear_closure_le {f : ℕ → Ordinal} {u : Ordinal}
    (h0 : f 0 ≤ u) (hstep : ∀ k, ∃ c : ℕ, f (k + 1) ≤ f k * c) :
    ⨆ k, f k ≤ u * ω := by
  have hbound : ∀ k, ∃ n : ℕ, f k ≤ u * n := by
    intro k
    induction k with
    | zero => exact ⟨1, by simpa using h0⟩
    | succ k ih =>
        obtain ⟨n, hfn⟩ := ih
        obtain ⟨c, hc⟩ := hstep k
        refine ⟨n * c, ?_⟩
        have hstep' : f (k + 1) ≤ u * ((n : Ordinal) * (c : Ordinal)) :=
          calc f (k + 1) ≤ f k * c := hc
            _ ≤ u * n * c := mul_le_mul_left hfn c
            _ = u * ((n : Ordinal) * (c : Ordinal)) := mul_assoc u n c
        rwa [Ordinal.natCast_mul]
  rw [Ordinal.iSup_le_iff]
  intro k
  obtain ⟨n, hfn⟩ := hbound k
  exact hfn.trans (mul_le_mul_right (natCast_lt_omega0 n).le u)

/-- Stratum 2 closed: a linear closure over a base below `ω ^ ω` stays below `ω ^ ω`. -/
theorem linear_closure_lt_omega0_opow_omega0 {f : ℕ → Ordinal} {u : Ordinal}
    (hu : u < ω ^ ω) (h0 : f 0 ≤ u) (hstep : ∀ k, ∃ c : ℕ, f (k + 1) ≤ f k * c) :
    ⨆ k, f k < ω ^ ω :=
  lt_of_le_of_lt (linear_closure_le h0 hstep)
    (isPrincipal_mul_omega0_opow_omega0 hu omega0_lt_omega0_opow_omega0)

/- ---------------------------------------------------------------- -/
/- Stratum 3: nonlinear closure spends the raised bound exactly.     -/
/- ---------------------------------------------------------------- -/

/-- Nonlinear closure squares its stage type each pass (`ω, ω², ω⁴, …`): the limit is exactly
`ω ^ ω` -- the binary-tree row's closure is the first universe of that type, spending the raised
bound and not overshooting it. -/
theorem nonlinear_closure_sup :
    ⨆ n : ℕ, (ω : Ordinal.{u}) ^ (2 ^ n : ℕ) = ω ^ (ω : Ordinal) := by
  apply le_antisymm
  · rw [Ordinal.iSup_le_iff]
    intro n
    rw [← opow_natCast]
    exact opow_le_opow_right omega0_pos (natCast_lt_omega0 _).le
  · rw [← iSup_pow_natCast omega0_pos, Ordinal.iSup_le_iff]
    intro n
    have hn : ω ^ n ≤ ω ^ (2 ^ n : ℕ) := by
      rw [← opow_natCast, ← opow_natCast]
      exact opow_le_opow_right omega0_pos (by exact_mod_cast (Nat.lt_two_pow_self).le)
    apply hn.trans
    exact Ordinal.le_iSup (fun n : ℕ => (ω : Ordinal.{u}) ^ (2 ^ n : ℕ)) n

/- ---------------------------------------------------------------- -/
/- The ceiling: no finite expression reaches epsilon_0.              -/
/- ---------------------------------------------------------------- -/

theorem isPrincipal_add_epsilon0 : IsPrincipal (· + ·) ε₀ := by
  have h := isPrincipal_add_omega0_opow ε₀
  rwa [omega0_opow_epsilon] at h

theorem isPrincipal_mul_epsilon0 : IsPrincipal (· * ·) ε₀ := by
  have h := isPrincipal_mul_omega0_opow_opow ε₀
  rwa [omega0_opow_epsilon, omega0_opow_epsilon] at h

theorem opow_lt_epsilon0 {a : Ordinal} (h : a < ε₀) : ω ^ a < ε₀ := by
  obtain ⟨n, hn⟩ := lt_epsilon_zero.1 h
  refine lt_epsilon_zero.2 ⟨n + 1, ?_⟩
  rw [Function.iterate_succ_apply']
  exact (opow_lt_opow_iff_right one_lt_omega0).2 hn

/-- "The limit sits at `ω ^ (α * ω)` for an `α` already under the bound": a stage sequence dominated
by the finite powers `ω ^ (α * k)` has its limit dominated by `ω ^ (α * ω)`. -/
theorem stages_le_climb {f : ℕ → Ordinal} {a : Ordinal}
    (hf : ∀ k, f k ≤ ω ^ (a * k)) : ⨆ k, f k ≤ ω ^ (a * ω) := by
  rw [Ordinal.iSup_le_iff]
  intro k
  exact (hf k).trans
    (opow_le_opow_right omega0_pos (mul_le_mul_right (natCast_lt_omega0 k).le a))

/-- The full order-type calculus of the floor: finite universes, the final segment's `ω`, union
sums, product products, and the closure limit `ω ^ (α * ω)` over a stage bound `α`
(`stages_le_climb`). Every finite expression's order type is built by these rules. -/
inductive L1Type : Ordinal → Prop
  | nat (n : ℕ) : L1Type n
  | omega : L1Type ω
  | add {a b : Ordinal} : L1Type a → L1Type b → L1Type (a + b)
  | mul {a b : Ordinal} : L1Type a → L1Type b → L1Type (a * b)
  | climb {a : Ordinal} : L1Type a → L1Type (ω ^ (a * ω))

/-- Headline (bounded transfinitude): no finite expression reaches `ε₀` -- order types grow by
ordinal sums, products, and closure limits alone, and each of those preserves the bound. -/
theorem l1Type_lt_epsilon0 {a : Ordinal} (h : L1Type a) : a < ε₀ := by
  induction h with
  | nat n => exact natCast_lt_epsilon n 0
  | omega => exact omega0_lt_epsilon 0
  | add _ _ iha ihb => exact isPrincipal_add_epsilon0 iha ihb
  | mul _ _ iha ihb => exact isPrincipal_mul_epsilon0 iha ihb
  | climb _ iha =>
      exact opow_lt_epsilon0 (isPrincipal_mul_epsilon0 iha (omega0_lt_epsilon 0))

end L1
