/- L1 order axis, phase B: positional value is mixed radix over a product of finite factors.

`docs/foundation/L1.md` (Positional value): "a tuple p_0 ... p_{k-1} over factor order types b_i
sits at sum_i W_i * value(p_i), summed most-significant term first with weight
W_i = b_{k-1} * b_{k-2} * ... * b_{i+1} on the left of its digit: mixed radix. ... Finite factors
give naturals, where the order of multiplication is invisible."

Phase A (`L1/Order/Order.lean`) proved the *uniform*-radix case: shortlex over a flat alphabet `Fin (m+1)`
is a well-order of type omega, reading a spelling as a base-`(m+1)` numeral (`lexIndex`). This file
generalizes that reading to a *product of finite factors* with per-factor radices `bs : List Nat`
(each factor's order type, most-significant first). A tuple is a digit list `ds` with `ds[i] < bs[i]`
at every position (`List.Forall₂ (· < ·) ds bs`), ordered positionally -- lexicographically on the
digits, which for the fixed length of a product is exactly `List.Lex (· < ·)`.

The `mixedRadix` reading below is the doc's sum written by Horner recursion:
`mixedRadix (b :: bs) (d :: ds) = d * bs.prod + mixedRadix bs ds`, where `bs.prod` is the product of
all radices to the right of the leading digit -- exactly the doc's weight `W_i`. The headline
`positional_value_type` cashes "finite factors give naturals": `mixedRadix` is an order isomorphism
from the positionally ordered tuples onto `(Fin bs.prod, <)`, so the product's order type is the
natural `bs.prod`. "The order of multiplication is invisible" is then immediate, since `bs.prod` is
a commutative `Nat` product. Read against Phase A, `lexIndex` is the special case
`bs = List.replicate _ (m + 1)`, proved as `lexIndex_eq_mixedRadix`.

Independent of the membership axis, exactly like `L1/Order/Order.lean`; `Code` stays `Nat` everywhere else. -/
import L1.Order.Order
import Mathlib.Data.List.Forall2
import Mathlib.Data.List.Lex
import Mathlib.Algebra.BigOperators.Group.List.Basic

namespace L1

/- ---------------------------------------------------------------- -/
/- The mixed-radix reading and its bound.                            -/
/- ---------------------------------------------------------------- -/

/-- The positional value of a digit list `ds` against radices `bs`, most-significant digit first.
`bs.prod` (the tail's product) is the doc's weight `W_0` on the leading digit; recursion carries the
same reading down the tail. Total on any lists; `mixedRadix_lt` is where validity pays for the
bound. -/
def mixedRadix : List Nat → List Nat → Nat
  | _, [] => 0
  | [], _ => 0
  | _b :: bs, d :: ds => d * bs.prod + mixedRadix bs ds

/-- A valid tuple's value is bounded by the product of the factor order types: it lands inside
`[0, bs.prod)`, the doc's `Fin bs.prod`. -/
theorem mixedRadix_lt : ∀ {ds bs : List Nat}, List.Forall₂ (· < ·) ds bs →
    mixedRadix bs ds < bs.prod
  | _, _, h => by
    induction h with
    | nil => simp [mixedRadix]
    | @cons d b ds bs hdb _ ih =>
        have hexpand : (d + 1) * bs.prod = d * bs.prod + bs.prod := by ring
        have hmul : (d + 1) * bs.prod ≤ b * bs.prod := Nat.mul_le_mul_right _ (by omega)
        simp only [mixedRadix, List.prod_cons]
        omega

/-- Positional order is value order: on valid same-shape tuples, `List.Lex` on the digits agrees
with `<` on their mixed-radix values. This is the order-embedding half of the isomorphism. -/
theorem mixedRadix_strictMono {a b bs : List Nat}
    (hlex : List.Lex (· < ·) a b)
    (ha : List.Forall₂ (· < ·) a bs) (hb : List.Forall₂ (· < ·) b bs) :
    mixedRadix bs a < mixedRadix bs b := by
  revert ha hb
  induction hlex generalizing bs with
  | nil => intro ha hb; cases ha; cases hb
  | @rel a1 l1 a2 l2 hr =>
      intro ha hb
      obtain ⟨_bR, bs', _, hl1, rfl⟩ := List.forall₂_cons_left_iff.mp ha
      cases hb with
      | cons _ hl2 =>
          have hbound : mixedRadix bs' l1 < bs'.prod := mixedRadix_lt hl1
          have hexpand : (a1 + 1) * bs'.prod = a1 * bs'.prod + bs'.prod := by ring
          have hmul : (a1 + 1) * bs'.prod ≤ a2 * bs'.prod := Nat.mul_le_mul_right _ (by omega)
          simp only [mixedRadix]
          omega
  | @cons a1 l1 l2 _ ih =>
      intro ha hb
      obtain ⟨_bR, bs', _, hl1, rfl⟩ := List.forall₂_cons_left_iff.mp ha
      cases hb with
      | cons _ hl2 =>
          have := ih hl1 hl2
          simp only [mixedRadix]
          omega

/- ---------------------------------------------------------------- -/
/- Decoding: every natural below the product is some tuple's value.  -/
/- ---------------------------------------------------------------- -/

/-- The tuple whose mixed-radix value is `r`: the leading digit is `r / bs.prod`, the rest decode the
remainder against the tail radices. Total on every `r`; `ofMixed_forall₂`/`ofMixed_mixedRadix` are
where `r < bs.prod` pays for validity and exactness. -/
def ofMixed : List Nat → Nat → List Nat
  | [], _ => []
  | _ :: bs, r => (r / bs.prod) :: ofMixed bs (r % bs.prod)

theorem ofMixed_forall₂ : ∀ {bs : List Nat} {r : Nat}, r < bs.prod →
    List.Forall₂ (· < ·) (ofMixed bs r) bs
  | [], r, _ => by simp only [ofMixed]; exact List.Forall₂.nil
  | b :: bs, r, hr => by
      simp only [List.prod_cons] at hr
      rcases Nat.eq_zero_or_pos bs.prod with hP | hP
      · simp [hP] at hr
      · have hdiv : r / bs.prod < b := by rw [Nat.div_lt_iff_lt_mul hP]; omega
        have hmod : r % bs.prod < bs.prod := Nat.mod_lt _ hP
        simp only [ofMixed]
        exact List.Forall₂.cons hdiv (ofMixed_forall₂ hmod)

theorem ofMixed_mixedRadix : ∀ {bs : List Nat} {r : Nat}, r < bs.prod →
    mixedRadix bs (ofMixed bs r) = r
  | [], r, hr => by
      simp only [List.prod_nil] at hr
      simp only [ofMixed, mixedRadix]; omega
  | b :: bs, r, hr => by
      simp only [List.prod_cons] at hr
      rcases Nat.eq_zero_or_pos bs.prod with hP | hP
      · simp [hP] at hr
      · have hmod : r % bs.prod < bs.prod := Nat.mod_lt _ hP
        have ih := ofMixed_mixedRadix (bs := bs) (r := r % bs.prod) hmod
        have hdm : bs.prod * (r / bs.prod) + r % bs.prod = r := Nat.div_add_mod r bs.prod
        have hcomm : r / bs.prod * bs.prod = bs.prod * (r / bs.prod) := Nat.mul_comm _ _
        simp only [ofMixed, mixedRadix, ih]
        omega

/- ---------------------------------------------------------------- -/
/- The positionally ordered tuple type and its order type.           -/
/- ---------------------------------------------------------------- -/

/-- A tuple over factors with order types `bs`: a digit list that is pointwise below the radices
(`Forall₂` also fixes the length to `bs.length`). -/
def Tuple (bs : List Nat) : Type := { ds : List Nat // List.Forall₂ (· < ·) ds bs }

/-- Positional order: lexicographic on the digits, most-significant first. -/
def tupleLt (bs : List Nat) : Tuple bs → Tuple bs → Prop :=
  fun x y => List.Lex (· < ·) x.val y.val

instance (bs : List Nat) : Std.Trichotomous (tupleLt bs) :=
  InvImage.trichotomous (r := List.Lex (· < ·)) (f := Subtype.val) Subtype.coe_injective

/-- The order embedding of a tuple into `Fin bs.prod` by its mixed-radix value. -/
def toFinVal (bs : List Nat) (x : Tuple bs) : Fin bs.prod :=
  ⟨mixedRadix bs x.val, mixedRadix_lt x.property⟩

theorem toFinVal_injective (bs : List Nat) : Function.Injective (toFinVal bs) := by
  intro x y h
  have hval : mixedRadix bs x.val = mixedRadix bs y.val := congrArg Fin.val h
  rcases trichotomous_of (tupleLt bs) x y with hlt | heq | hgt
  · exact absurd hval (Nat.ne_of_lt (mixedRadix_strictMono hlt x.property y.property))
  · exact heq
  · exact absurd hval.symm (Nat.ne_of_lt (mixedRadix_strictMono hgt y.property x.property))

theorem toFinVal_surjective (bs : List Nat) : Function.Surjective (toFinVal bs) := by
  intro y
  refine ⟨⟨ofMixed bs y.val, ofMixed_forall₂ y.isLt⟩, ?_⟩
  apply Fin.ext
  simp only [toFinVal]
  exact ofMixed_mixedRadix y.isLt

/-- `mixedRadix` witnesses an order isomorphism between the positionally ordered tuples and
`(Fin bs.prod, <)`. -/
noncomputable def posValueIso (bs : List Nat) :
    (tupleLt bs) ≃r ((· < ·) : Fin bs.prod → Fin bs.prod → Prop) where
  toEquiv := Equiv.ofBijective (toFinVal bs) ⟨toFinVal_injective bs, toFinVal_surjective bs⟩
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply, toFinVal, Fin.lt_def]
    constructor
    · intro hv
      rcases trichotomous_of (tupleLt bs) x y with h | h | h
      · exact h
      · rw [h] at hv; exact absurd hv (lt_irrefl _)
      · have hcontra := mixedRadix_strictMono h y.property x.property
        omega
    · intro h; exact mixedRadix_strictMono h x.property y.property

instance (bs : List Nat) : IsWellOrder (Tuple bs) (tupleLt bs) :=
  (posValueIso bs).toRelEmbedding.isWellOrder

/-- Positional value, phase B: a product of finite factors with order types `bs`, ordered by
positional value, has order type exactly the natural `bs.prod`. "Finite factors give naturals";
`bs.prod` is commutative, so "the order of multiplication is invisible." -/
theorem positional_value_type (bs : List Nat) :
    Ordinal.type (tupleLt bs) = (bs.prod : Ordinal) :=
  (Ordinal.type_eq.mpr ⟨posValueIso bs⟩).trans (Ordinal.type_fin bs.prod)

/- ---------------------------------------------------------------- -/
/- Bridge back to phase A: the flat alphabet is the uniform radix.   -/
/- ---------------------------------------------------------------- -/

/-- Phase A's `lexIndex` is this phase's `mixedRadix` at the uniform radix `m + 1`: reading a
spelling over `Fin (m + 1)` as a base-`(m+1)` numeral is exactly the mixed-radix reading against the
constant radix list. This cashes `L1/Order/Order.lean`'s header claim that `lexIndex` previews positional
value. -/
theorem lexIndex_eq_mixedRadix (m : Nat) (l : FSpelling m) :
    lexIndex m l = mixedRadix (List.replicate l.length (m + 1)) (l.map Fin.val) := by
  induction l with
  | nil => simp [lexIndex, mixedRadix]
  | cons a rest ih =>
      simp only [List.length_cons, List.replicate_succ, List.map_cons, lexIndex, mixedRadix,
        List.prod_replicate, ih]

end L1
