/- L1 order axis: canonical numerals of a sub-range head radix, abstract half.

`docs/foundation/L1.md` (Canonical numerals): "where every digit face is a single code point and
the digits stand in code-point order, value order and spelling order agree on the canonical
numerals of the radix. No leading zero digit, so the wider numeral is always the larger value; and
within one width positional order reads digit by digit -- exactly shortlex's tie-break."

Phase A's `fshortlex_iff_value_lt` is the full-space statement: `value` is the shortlex *rank*
(length-class offset plus numeral), total on every spelling. This file proves the doc's actual
numerals claim: on the canonical spellings alone -- the single zero digit, plus every spelling
whose leading digit is drawn from the *sub-range* `{1..m}` of the head -- the bare positional
reading `lexIndex` (no offset) is already the shortlex order. The two premises of the doc bite
exactly here: `pow_le_lexIndex` is the no-leading-zero lower bound that makes the wider numeral
the larger value, and `lexIndex_lt_of_lex` (phase A) is the within-width tie-break.

The enumeration half needs `0 < m`: at radix 1 the only canonical numeral is the zero digit, so
`lexIndex` is not surjective onto `Nat` and the order type is `1`, not `omega0`. The order
agreement `numeral_fshortlex_iff_lexIndex_lt` holds unconditionally.

The real-syntax half -- the same statement read off the north-star term `{0, {1..9, &{0..9}}}`
with the real stage ladder supplying first appearance -- is `L1/Bridge/Numerals.lean`. -/
import L1.Order.Order

namespace L1

variable (m : Nat)

/-- A canonical numeral: the single zero digit, or a spelling led by a nonzero digit. The leading
digit ranges over the sub-range `{1..m}` of the head where every later digit ranges over the full
`{0..m}` -- the shape the north-star row `{0, {1..9, &{0..9}}}` spells at radix ten. -/
def IsNumeral (l : FSpelling m) : Prop := ∃ c r, l = c :: r ∧ (0 < c.val ∨ r = [])

/-- The no-leading-zero lower bound: a nonzero leading digit puts the numeral at or above its
width's opening value. This is the doc's "the wider numeral is always the larger value" premise --
a leading zero would sit below the bound and part the two orders. -/
theorem pow_le_lexIndex {c : FCode m} {r : List (FCode m)} (h : 0 < c.val) :
    (m + 1) ^ r.length ≤ lexIndex m (c :: r) := by
  have hmul : (m + 1) ^ r.length ≤ c.val * (m + 1) ^ r.length :=
    Nat.le_mul_of_pos_left _ h
  simp only [lexIndex]
  omega

/-- Cross-width case: on canonical numerals the strictly wider spelling holds the strictly larger
value -- the widths partition the value line in width order. -/
theorem numeral_lexIndex_lt_of_length_lt {l1 l2 : FSpelling m}
    (h1 : IsNumeral m l1) (h2 : IsNumeral m l2) (h : l1.length < l2.length) :
    lexIndex m l1 < lexIndex m l2 := by
  obtain ⟨c1, r1, rfl, -⟩ := h1
  obtain ⟨c2, r2, rfl, hc2⟩ := h2
  have hr2 : r2 ≠ [] := by
    intro hnil
    subst hnil
    simp only [List.length_cons, List.length_nil] at h
    omega
  have hc2' : 0 < c2.val := hc2.resolve_right hr2
  calc lexIndex m (c1 :: r1)
      < (m + 1) ^ (c1 :: r1).length := lexIndex_lt_pow m _
    _ ≤ (m + 1) ^ r2.length := by
        refine Nat.pow_le_pow_right (Nat.succ_pos m) ?_
        simp only [List.length_cons] at h ⊢
        omega
    _ ≤ lexIndex m (c2 :: r2) := pow_le_lexIndex m hc2'

/-- `lexIndex` is strictly monotone along shortlex on the canonical numerals: cross-width by the
no-leading-zero bound, within a width by phase A's positional tie-break. -/
theorem numeral_lexIndex_strictMono {l1 l2 : FSpelling m}
    (h1 : IsNumeral m l1) (h2 : IsNumeral m l2) (h : fshortlex m l1 l2) :
    lexIndex m l1 < lexIndex m l2 := by
  rcases List.shortlex_def.mp h with hlt | ⟨heq, hlex⟩
  · exact numeral_lexIndex_lt_of_length_lt m h1 h2 hlt
  · exact lexIndex_lt_of_lex m hlex heq

/-- The doc's canonical-numerals theorem, abstract half: on the canonical numerals of a sub-range
head radix, value order and spelling order agree. Unconditional in the radix -- both premises are
carried by `IsNumeral` itself. -/
theorem numeral_fshortlex_iff_lexIndex_lt {l1 l2 : FSpelling m}
    (h1 : IsNumeral m l1) (h2 : IsNumeral m l2) :
    fshortlex m l1 l2 ↔ lexIndex m l1 < lexIndex m l2 := by
  constructor
  · exact numeral_lexIndex_strictMono m h1 h2
  · intro hv
    rcases trichotomous_of (fshortlex m) l1 l2 with h | h | h
    · exact h
    · subst h; omega
    · have := numeral_lexIndex_strictMono m h2 h1 h
      omega

/- ---------------------------------------------------------------- -/
/- The enumeration: every value wears exactly one canonical numeral. -/
/- ---------------------------------------------------------------- -/

/-- The canonical numeral of a value: the zero digit for `0`, otherwise the `log`-plus-one-digit
positional spelling -- whose leading digit is forced nonzero by the width being exactly the log. -/
def numeralOfNat (n : Nat) : FSpelling m :=
  if n = 0 then [0] else ofIndex m (Nat.log (m + 1) n + 1) n

theorem numeralOfNat_lexIndex (hm : 0 < m) (n : Nat) :
    lexIndex m (numeralOfNat m n) = n := by
  by_cases hn : n = 0
  · subst hn
    rw [numeralOfNat, if_pos rfl]
    simp [lexIndex]
  · rw [numeralOfNat, if_neg hn]
    exact ofIndex_lexIndex m _ n (Nat.lt_pow_succ_log_self (by omega) n)

theorem numeralOfNat_isNumeral (hm : 0 < m) (n : Nat) :
    IsNumeral m (numeralOfNat m n) := by
  by_cases hn : n = 0
  · subst hn
    exact ⟨0, [], by simp [numeralOfNat], Or.inr rfl⟩
  · rw [numeralOfNat, if_neg hn]
    have hpow : 0 < (m + 1) ^ Nat.log (m + 1) n := pow_pos (Nat.succ_pos m) _
    have hle : (m + 1) ^ Nat.log (m + 1) n ≤ n := Nat.pow_log_le_self (m + 1) hn
    have hlt : n < (m + 1) ^ (Nat.log (m + 1) n + 1) :=
      Nat.lt_pow_succ_log_self (by omega) n
    have hdiv1 : 1 ≤ n / (m + 1) ^ Nat.log (m + 1) n :=
      (Nat.one_le_div_iff hpow).mpr hle
    have hdivlt : n / (m + 1) ^ Nat.log (m + 1) n < m + 1 := by
      rw [Nat.div_lt_iff_lt_mul hpow]
      calc n < (m + 1) ^ (Nat.log (m + 1) n + 1) := hlt
        _ = (m + 1) * (m + 1) ^ Nat.log (m + 1) n := by ring
    refine ⟨_, _, rfl, Or.inl ?_⟩
    show 0 < (n / (m + 1) ^ Nat.log (m + 1) n) % (m + 1)
    rw [Nat.mod_eq_of_lt hdivlt]
    omega

/-- Spelling order restricted to the canonical numerals. -/
def numeralLt : Subtype (IsNumeral m) → Subtype (IsNumeral m) → Prop :=
  Subrel (fshortlex m) (IsNumeral m)

instance : IsWellOrder (Subtype (IsNumeral m)) (numeralLt m) :=
  inferInstanceAs (IsWellOrder _ (Subrel _ _))

/-- `lexIndex` witnesses an order isomorphism between the canonical numerals in shortlex and
`(Nat, <)`: every value wears exactly one canonical numeral, in value order. Needs a genuine
radix (`0 < m`) -- at radix 1 the zero digit is the only canonical numeral. -/
noncomputable def numeralValueIso (hm : 0 < m) :
    numeralLt m ≃r ((· < ·) : Nat → Nat → Prop) :=
  RelIso.ofSurjective
    (RelEmbedding.ofMonotone (fun l => lexIndex m l.val)
      (fun a b h => numeral_lexIndex_strictMono m a.2 b.2 h))
    (fun n => ⟨⟨numeralOfNat m n, numeralOfNat_isNumeral m hm n⟩, numeralOfNat_lexIndex m hm n⟩)

/-- The canonical numerals in shortlex have order type exactly `omega0`: the sub-range-radix
companion to phase A's `finShortlex_type_omega0`. -/
theorem numeralShortlex_type_omega0 (hm : 0 < m) :
    Ordinal.type (numeralLt m) = Ordinal.omega0 := by
  rw [Ordinal.type_eq.mpr ⟨numeralValueIso m hm⟩]
  exact Ordinal.type_nat_lt

end L1
