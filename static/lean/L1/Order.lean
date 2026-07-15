/- L1 order axis, phase A: shortlex over a finite alphabet is a well-order of type omega.

`docs/foundation/L1.md` (Spelling order): "the code-point set is finite, so this [shortlex] is a
well-order of type omega." The membership axis (`Spelling.lean` through `NorthStar.lean`) works over
`Code := Nat`, an infinite alphabet -- correct for membership, but shortlex over it is only a total
order, not a well-order of type omega, exactly because each length class is itself infinite
(`Spelling.lean`'s header explains why, and is left untouched here). This file proves the doc's claim
on a genuinely finite alphabet `Fin (m + 1)`: any finite, nonempty, linearly ordered alphabet is
order-isomorphic to some such `Fin (m + 1)`, so this is the general finite case, not a special one.
Purely additive: nothing in the membership axis changes.

Reuses Mathlib's `List.Shortlex` (`Mathlib.Data.List.Shortlex`) rather than reproving
irreflexivity/transitivity/totality by hand the way `Spelling.lean`'s bespoke `Bool`-valued
`shortlexLt` did: `IsWellOrder` only needs well-foundedness (`List.Shortlex.wf`, given here by
`Fin (m+1)`'s order being well-founded) and trichotomy (`List.Shortlex.trichotomous`, given here by
`Fin (m+1)`'s linear order) -- `IsTrans` then comes for free as a derived instance.

The remaining work is the enumeration `value`: an explicit order isomorphism onto `(Nat, <)`, read as
a base-`(m+1)` numeral with a length-class offset (`lenOffset`, `lexIndex`). Its existence forces the
order type to be exactly `omega0`, since `omega0` is *defined* as the order type of `(Nat, <)`
(`Ordinal.type_nat_lt`). `lexIndex` doubles as a preview of Phase C's positional-value theorem: it is
already the mixed-radix reading the doc's "Positional value" theorem generalizes to products. -/
import Mathlib.Tactic
import Mathlib.Data.List.Shortlex
import Mathlib.SetTheory.Ordinal.Basic

namespace L1

variable (m : Nat)

/-- Phase A's alphabet: `m + 1` code points. Any finite nonempty linearly ordered alphabet is
order-isomorphic to some `Fin (m + 1)`, so this is WLOG the general finite case. -/
abbrev FCode := Fin (m + 1)

abbrev FSpelling := List (FCode m)

/-- Reuse Mathlib's shortlex relation rather than the bespoke Bool-valued one in `Spelling.lean`. -/
def fshortlex : FSpelling m → FSpelling m → Prop := List.Shortlex (α := FCode m) (· < ·)

instance : IsWellFounded (FSpelling m) (fshortlex m) :=
  ⟨List.Shortlex.wf (wellFounded_lt)⟩

instance : Std.Trichotomous (fshortlex m) := List.Shortlex.trichotomous

instance : IsWellOrder (FSpelling m) (fshortlex m) where

/- ---------------------------------------------------------------- -/
/- The enumeration: length-class offset plus a base-(m+1) numeral.   -/
/- ---------------------------------------------------------------- -/

/-- How many spellings sort strictly before every spelling of length `k`, i.e. every shorter
spelling: the sum of `(m+1)^i` for `i < k`. -/
def lenOffset : Nat → Nat
  | 0 => 0
  | k + 1 => lenOffset k + (m + 1) ^ k

/-- The base-`(m+1)` numeral for a spelling, most-significant digit first -- the same reading the
doc's positional-value theorem uses for products. -/
def lexIndex : FSpelling m → Nat
  | [] => 0
  | a :: rest => a.val * (m + 1) ^ rest.length + lexIndex rest

def value (l : FSpelling m) : Nat := lenOffset m l.length + lexIndex m l

theorem lexIndex_lt_pow : ∀ l : FSpelling m, lexIndex m l < (m + 1) ^ l.length
  | [] => by simp [lexIndex]
  | a :: rest => by
      have ha : a.val ≤ m := Nat.lt_succ_iff.mp a.isLt
      have hrest := lexIndex_lt_pow rest
      have hmul : a.val * (m + 1) ^ rest.length ≤ m * (m + 1) ^ rest.length :=
        Nat.mul_le_mul_right _ ha
      have hexpand : (m + 1) * (m + 1) ^ rest.length
          = m * (m + 1) ^ rest.length + (m + 1) ^ rest.length := by ring
      simp only [lexIndex, List.length_cons, pow_succ']
      omega

theorem lenOffset_ge : ∀ k, k ≤ lenOffset m k
  | 0 => le_refl 0
  | k + 1 => by
      have ih := lenOffset_ge k
      have hpow : 0 < (m + 1) ^ k := pow_pos (Nat.succ_pos m) k
      simp only [lenOffset]
      omega

theorem lenOffset_strictMono : StrictMono (lenOffset m) :=
  strictMono_nat_of_lt_succ (fun k => by
    have hpow : 0 < (m + 1) ^ k := pow_pos (Nat.succ_pos m) k
    simp only [lenOffset]
    omega)

/-- Cross-length case: a strictly shorter spelling always sorts strictly earlier. -/
theorem value_lt_of_length_lt {l1 l2 : FSpelling m} (h : l1.length < l2.length) :
    value m l1 < value m l2 := by
  have h1 : value m l1 < lenOffset m (l1.length + 1) := by
    have := lexIndex_lt_pow m l1
    simp only [value, lenOffset]
    omega
  have h2 : lenOffset m (l1.length + 1) ≤ lenOffset m l2.length :=
    (lenOffset_strictMono m).monotone (by omega)
  have h3 : lenOffset m l2.length ≤ value m l2 := by simp only [value]; omega
  omega

/-- Same-length case: `List.Lex` order on the digits matches `lexIndex` order. -/
theorem lexIndex_lt_of_lex {l1 l2 : FSpelling m} (h : List.Lex (α := FCode m) (· < ·) l1 l2) :
    l1.length = l2.length → lexIndex m l1 < lexIndex m l2 := by
  induction h with
  | nil => intro hlen; simp at hlen
  | @rel a l1' b l2' hab =>
      intro hlen
      simp only [List.length_cons, Nat.add_right_cancel_iff] at hlen
      have hb : a.val < b.val := hab
      have hrest := lexIndex_lt_pow m l1'
      have hmul : (a.val + 1) * (m + 1) ^ l1'.length ≤ b.val * (m + 1) ^ l1'.length :=
        Nat.mul_le_mul_right _ (by omega)
      have hexpand : (a.val + 1) * (m + 1) ^ l1'.length
          = a.val * (m + 1) ^ l1'.length + (m + 1) ^ l1'.length := by ring
      simp only [lexIndex]
      rw [← hlen]
      omega
  | @cons a l1' l2' _ ih =>
      intro hlen
      simp only [List.length_cons, Nat.add_right_cancel_iff] at hlen
      have := ih hlen
      simp only [lexIndex, hlen]
      omega

/-- `value` is strictly monotone with respect to `fshortlex`. -/
theorem value_strictMono' {l1 l2 : FSpelling m} (h : fshortlex m l1 l2) :
    value m l1 < value m l2 := by
  rcases List.shortlex_def.mp h with hlt | ⟨heq, hlex⟩
  · exact value_lt_of_length_lt m hlt
  · have hidx := lexIndex_lt_of_lex m hlex heq
    simp only [value]
    rw [heq]
    omega

theorem value_injective : Function.Injective (value m) := by
  intro l1 l2 heq
  rcases trichotomous_of (fshortlex m) l1 l2 with h | h | h
  · exact absurd heq (Nat.ne_of_lt (value_strictMono' m h))
  · exact h
  · exact absurd heq.symm (Nat.ne_of_lt (value_strictMono' m h))

/- ---------------------------------------------------------------- -/
/- Surjectivity: every natural is the value of some spelling.        -/
/- ---------------------------------------------------------------- -/

/-- The `k`-digit base-`(m+1)` numeral for `r`, most-significant digit first. Total on every `r`
(not just `r < (m+1)^k`) via `% (m+1)` on the leading digit, so this typechecks unconditionally;
`ofIndex_lexIndex` below is where the `r < (m+1)^k` hypothesis pays for exactness. -/
def ofIndex : (k : Nat) → (r : Nat) → FSpelling m
  | 0, _ => []
  | k + 1, r =>
      (⟨(r / (m + 1) ^ k) % (m + 1), Nat.mod_lt _ (Nat.succ_pos m)⟩ : FCode m) ::
        ofIndex k (r % (m + 1) ^ k)

theorem ofIndex_length : ∀ k r, (ofIndex m k r).length = k
  | 0, _ => rfl
  | k + 1, r => by simp [ofIndex, ofIndex_length k]

theorem ofIndex_lexIndex : ∀ k r, r < (m + 1) ^ k → lexIndex m (ofIndex m k r) = r
  | 0, r, hr => by
      simp only [pow_zero] at hr
      have hr0 : r = 0 := by omega
      subst hr0
      simp [ofIndex, lexIndex]
  | k + 1, r, hr => by
      have hpow : 0 < (m + 1) ^ k := pow_pos (Nat.succ_pos m) k
      have hpow1 : (m + 1) ^ (k + 1) = (m + 1) * (m + 1) ^ k := by ring
      have hdiv : r / (m + 1) ^ k < m + 1 := by
        rw [Nat.div_lt_iff_lt_mul hpow]; omega
      have hmod : (r / (m + 1) ^ k) % (m + 1) = r / (m + 1) ^ k := Nat.mod_eq_of_lt hdiv
      have hmodr : r % (m + 1) ^ k < (m + 1) ^ k := Nat.mod_lt _ hpow
      have ih := ofIndex_lexIndex k (r % (m + 1) ^ k) hmodr
      have hdm : (m + 1) ^ k * (r / (m + 1) ^ k) + r % (m + 1) ^ k = r := Nat.div_add_mod r _
      have hcomm : r / (m + 1) ^ k * (m + 1) ^ k = (m + 1) ^ k * (r / (m + 1) ^ k) :=
        Nat.mul_comm _ _
      simp only [ofIndex, lexIndex, ofIndex_length, hmod]
      omega

theorem value_surjective : Function.Surjective (value m) := by
  intro n
  obtain ⟨k, hle, hlt⟩ : ∃ k, lenOffset m k ≤ n ∧ n < lenOffset m (k + 1) := by
    refine ⟨Nat.findGreatest (fun j => lenOffset m j ≤ n) n, ?_, ?_⟩
    · have h0 : lenOffset m 0 ≤ n := by have : lenOffset m 0 = 0 := rfl; omega
      exact Nat.findGreatest_spec (P := fun j => lenOffset m j ≤ n) (Nat.zero_le n) h0
    · rcases Nat.lt_or_ge (Nat.findGreatest (fun j => lenOffset m j ≤ n) n) n with hklt | hkge
      · have hnp : ¬ lenOffset m (Nat.findGreatest (fun j => lenOffset m j ≤ n) n + 1) ≤ n :=
          Nat.findGreatest_is_greatest (P := fun j => lenOffset m j ≤ n) (n := n)
            (k := Nat.findGreatest (fun j => lenOffset m j ≤ n) n + 1) (by omega) (by omega)
        omega
      · have hkeq : Nat.findGreatest (fun j => lenOffset m j ≤ n) n = n :=
          le_antisymm (Nat.findGreatest_le n) hkge
        have hge := lenOffset_ge m (n + 1)
        rw [hkeq]
        omega
  have hoff : lenOffset m (k + 1) = lenOffset m k + (m + 1) ^ k := rfl
  refine ⟨ofIndex m k (n - lenOffset m k), ?_⟩
  have hrlt : n - lenOffset m k < (m + 1) ^ k := by omega
  have hlen := ofIndex_length m k (n - lenOffset m k)
  have hidx := ofIndex_lexIndex m k (n - lenOffset m k) hrlt
  simp only [value, hlen, hidx]
  omega

/- ---------------------------------------------------------------- -/
/- The headline theorem: shortlex over a finite alphabet has type omega. -/
/- ---------------------------------------------------------------- -/

/-- `value` witnesses an order isomorphism between `fshortlex` and `(Nat, <)`. -/
noncomputable def valueRelIso : (fshortlex m) ≃r ((· < ·) : Nat → Nat → Prop) where
  toEquiv := Equiv.ofBijective (value m) ⟨value_injective m, value_surjective m⟩
  map_rel_iff' := by
    intro l1 l2
    simp only [Equiv.ofBijective_apply]
    constructor
    · intro hv
      rcases trichotomous_of (fshortlex m) l1 l2 with h | h | h
      · exact h
      · rw [h] at hv; exact absurd hv (lt_irrefl _)
      · have hcontra := value_strictMono' m h
        omega
    · exact value_strictMono' m

theorem finShortlex_type_omega0 : Ordinal.type (fshortlex m) = Ordinal.omega0 := by
  rw [Ordinal.type_eq.mpr ⟨valueRelIso m⟩]
  exact Ordinal.type_nat_lt

end L1
