/- L1 spelling order: codes, spellings, shortlex, and half-open windows.

Port of `static/formal/L1/Spelling.v`, mirroring `Himark/core/order.py` at
the membership level. Code points are all of `Nat` rather than a finite set,
so the shortlex order here is a total order but not of order type omega (each
length class is already infinite); the type-omega claim needs the finite
code-point set and is deferred with the rest of the order axis. One
consequence is exact successors: the successor of the singleton `[z]` is
`[z+1]`, with no rollover case, which is all the range constructor needs.
Finitizing the alphabet will change exactly this: `rangeWindow`'s `[hi + 1]`
bound has no code successor at the greatest code point, where the shortlex
successor of `[max]` is the least length-2 spelling instead.

Where Coq wrote its own `spelling_eqb`, Lean reuses the `LawfulBEq (List Nat)`
instance: `s == t` decides `s = t`, so `beq_iff_eq` replaces the hand-rolled
`spelling_eqb_eq`. -/
import Mathlib.Tactic
import Mathlib.Data.List.Shortlex

namespace L1

-- `notation` rather than `abbrev` so a variable of type `Code` is literally
-- `Nat`: `omega` refuses to reason about a reducible type synonym but is happy
-- with `Nat` itself, and code arithmetic runs through `omega` everywhere.
notation "Code" => Nat
notation "Spelling" => List Nat

/- ---------------------------------------------------------------- -/
/- Lexicographic order on equal-length spellings (dictionary form). -/
/- ---------------------------------------------------------------- -/

def lexLt : Spelling → Spelling → Bool
  | _, [] => false
  | [], _ :: _ => true
  | a :: s, b :: t => a < b || (a == b && lexLt s t)

@[simp] theorem lexLt_nil_right (s : Spelling) : lexLt s [] = false := by
  cases s <;> rfl

theorem lexLt_irrefl : ∀ s, lexLt s s = false
  | [] => rfl
  | a :: s => by simp [lexLt, lexLt_irrefl s]

theorem lexLt_trans :
    ∀ {s t u}, lexLt s t = true → lexLt t u = true → lexLt s u = true
  | _, [], _, hst, _ => by simp at hst
  | [], _ :: _, [], _, htu => by simp at htu
  | [], _ :: _, _ :: _, _, _ => rfl
  | _ :: _, _ :: _, [], _, htu => by simp at htu
  | a :: s, b :: t, c :: u, hst, htu => by
      simp only [lexLt, Bool.or_eq_true, Bool.and_eq_true, beq_iff_eq,
        decide_eq_true_eq] at hst htu ⊢
      rcases hst with h1 | ⟨h1, h1'⟩ <;> rcases htu with h2 | ⟨h2, h2'⟩
      · exact Or.inl (by omega)
      · exact Or.inl (by omega)
      · exact Or.inl (by omega)
      · exact Or.inr ⟨by omega, lexLt_trans h1' h2'⟩

theorem lexLt_total : ∀ s t, lexLt s t = true ∨ s = t ∨ lexLt t s = true
  | [], [] => Or.inr (Or.inl rfl)
  | [], _ :: _ => Or.inl rfl
  | _ :: _, [] => Or.inr (Or.inr rfl)
  | a :: s, b :: t => by
      rcases Nat.lt_trichotomy a b with h | h | h
      · exact Or.inl (by simp [lexLt, h])
      · subst h
        rcases lexLt_total s t with h | h | h
        · exact Or.inl (by simp [lexLt, h])
        · subst h; exact Or.inr (Or.inl rfl)
        · exact Or.inr (Or.inr (by simp [lexLt, h]))
      · exact Or.inr (Or.inr (by simp [lexLt, h]))

/- ---------------------------------------------------------------- -/
/- Shortlex: shorter first, ties broken lexicographically.          -/
/- ---------------------------------------------------------------- -/

def shortlexLt (s t : Spelling) : Bool :=
  s.length < t.length || (s.length == t.length && lexLt s t)

def shortlexLe (s t : Spelling) : Bool :=
  shortlexLt s t || (s == t)

theorem shortlexLt_irrefl (s : Spelling) : shortlexLt s s = false := by
  simp [shortlexLt, lexLt_irrefl]

theorem shortlexLt_trans {s t u : Spelling} :
    shortlexLt s t = true → shortlexLt t u = true → shortlexLt s u = true := by
  simp only [shortlexLt, Bool.or_eq_true, Bool.and_eq_true, beq_iff_eq,
    decide_eq_true_eq]
  intro hst htu
  rcases hst with h1 | ⟨h1, h1'⟩ <;> rcases htu with h2 | ⟨h2, h2'⟩
  · exact Or.inl (by omega)
  · exact Or.inl (by omega)
  · exact Or.inl (by omega)
  · exact Or.inr ⟨by omega, lexLt_trans h1' h2'⟩

theorem shortlexLt_asym {s t : Spelling} :
    shortlexLt s t = true → shortlexLt t s = true → False := by
  intro hst hts
  have := shortlexLt_trans hst hts
  rw [shortlexLt_irrefl] at this
  exact Bool.noConfusion this

theorem shortlex_total (s t : Spelling) :
    shortlexLt s t = true ∨ s = t ∨ shortlexLt t s = true := by
  rcases Nat.lt_trichotomy s.length t.length with h | h | h
  · exact Or.inl (by simp [shortlexLt, h])
  · rcases lexLt_total s t with hl | hl | hl
    · exact Or.inl (by simp [shortlexLt, h, hl])
    · exact Or.inr (Or.inl hl)
    · exact Or.inr (Or.inr (by simp [shortlexLt, h, hl]))
  · exact Or.inr (Or.inr (by simp [shortlexLt, h]))

/- ---------------------------------------------------------------- -/
/- Bridge to Mathlib's `List.Shortlex`: the bespoke Bool-valued order -/
/- here (infinite alphabet, feeds the evaluator) agrees with the      -/
/- Prop-valued order the order axis uses (`Order.lean`'s `fshortlex`  -/
/- is `List.Shortlex (· < ·)` over `Fin (m+1)`), certifying the two   -/
/- shortlex theories cannot silently disagree on their shared domain. -/
/- ---------------------------------------------------------------- -/

/-- The Bool-valued dictionary order agrees with Mathlib's `List.Lex`. -/
theorem lexLt_iff_lex : ∀ s t : Spelling, lexLt s t = true ↔ List.Lex (· < ·) s t
  | _, [] => by
      simp only [lexLt_nil_right, Bool.false_eq_true, false_iff]
      intro h; cases h
  | [], _ :: _ => by
      simp only [lexLt]
      exact iff_of_true trivial List.Lex.nil
  | a :: s, b :: t => by
      simp only [lexLt, Bool.or_eq_true, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq]
      rw [lexLt_iff_lex s t]
      constructor
      · rintro (hlt | ⟨rfl, hrec⟩)
        · exact List.Lex.rel hlt
        · exact List.Lex.cons hrec
      · intro h
        cases h with
        | rel h => exact Or.inl h
        | cons h => exact Or.inr ⟨rfl, h⟩

/-- The bespoke `shortlexLt` decides exactly Mathlib's `List.Shortlex (· < ·)`, the relation
`Order.lean`'s `fshortlex` is defined as. Neither order can silently drift from the other. -/
theorem shortlexLt_iff_fshortlex (s t : Spelling) :
    shortlexLt s t = true ↔ List.Shortlex (· < ·) s t := by
  rw [List.shortlex_def]
  simp only [shortlexLt, Bool.or_eq_true, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq]
  rw [lexLt_iff_lex s t]

/-- The connective identity: strictly-below is exactly not-at-or-above. -/
theorem shortlexLt_not_le (s t : Spelling) :
    shortlexLt s t = !(shortlexLe t s) := by
  rcases shortlex_total s t with h | h | h
  · have h1 : shortlexLt t s = false := by
      cases e : shortlexLt t s with
      | false => rfl
      | true => exact absurd (shortlexLt_asym h e) (by simp)
    have h2 : (t == s) = false := by
      cases e : (t == s) with
      | false => rfl
      | true =>
          rw [beq_iff_eq] at e; subst e
          rw [shortlexLt_irrefl] at h; exact absurd h (by simp)
    simp [shortlexLe, h, h1, h2]
  · subst h; simp [shortlexLe, shortlexLt_irrefl]
  · have h1 : shortlexLt s t = false := by
      cases e : shortlexLt s t with
      | false => rfl
      | true => exact absurd (shortlexLt_asym e h) (by simp)
    simp [shortlexLe, h, h1]

theorem shortlexLe_refl (s : Spelling) : shortlexLe s s = true := by
  simp [shortlexLe]

theorem shortlexLe_trans {s t u : Spelling} :
    shortlexLe s t = true → shortlexLe t u = true → shortlexLe s u = true := by
  simp only [shortlexLe, Bool.or_eq_true, beq_iff_eq]
  rintro (hst | rfl) (htu | rfl)
  · exact Or.inl (shortlexLt_trans hst htu)
  · exact Or.inl hst
  · exact Or.inl htu
  · exact Or.inr rfl

theorem shortlexLe_lt_trans {s t u : Spelling} :
    shortlexLe s t = true → shortlexLt t u = true → shortlexLt s u = true := by
  simp only [shortlexLe, Bool.or_eq_true, beq_iff_eq]
  rintro (hst | rfl) htu
  · exact shortlexLt_trans hst htu
  · exact htu

theorem singleton_shortlexLt {a b : Code} (h : a < b) :
    shortlexLt [a] [b] = true := by simp [shortlexLt, lexLt, h]

theorem singleton_shortlexLe {a b : Code} (h : a ≤ b) :
    shortlexLe [a] [b] = true := by
  simp only [shortlexLe, Bool.or_eq_true]
  rcases Nat.eq_or_lt_of_le h with rfl | h
  · exact Or.inr (by simp)
  · exact Or.inl (singleton_shortlexLt h)

/-- Mirrors `singleton_ltb_iff` in `Spelling.v`. -/
theorem singleton_shortlexLt_iff (a b : Code) :
    shortlexLt [a] [b] = true ↔ a < b := by
  simp [shortlexLt, lexLt]

theorem singleton_shortlexLe_iff (a b : Code) :
    shortlexLe [a] [b] = true ↔ a ≤ b := by
  simp only [shortlexLe, Bool.or_eq_true, singleton_shortlexLt_iff, beq_iff_eq,
    List.cons.injEq, and_true]
  omega

/- ---------------------------------------------------------------- -/
/- Half-open shortlex windows [lo, hi); hi = none means unbounded.  -/
/- ---------------------------------------------------------------- -/

structure Window : Type where
  wlo : Spelling
  whi : Option Spelling

def winb (w : Window) (s : Spelling) : Bool :=
  shortlexLe w.wlo s &&
    (match w.whi with
     | none => true
     | some h => shortlexLt s h)

/-- A final segment `{lo..}` is `[lo, infinity)`. -/
def finalWindow (lo : Spelling) : Window := ⟨lo, none⟩

/-- A range `{lo..hi}` over single code points is `[[lo], [hi+1])` --
successors are exact because codes are all of `Nat`. -/
def rangeWindow (lo hi : Code) : Window := ⟨[lo], some [hi + 1]⟩

/-- A bounded window is the difference of two final segments. -/
theorem winb_final_diff (lo hi s : Spelling) :
    (winb ⟨lo, none⟩ s && !(winb ⟨hi, none⟩ s)) = winb ⟨lo, some hi⟩ s := by
  simp only [winb, Bool.and_true]
  rw [shortlexLt_not_le s hi]

theorem winb_range_diff (lo hi : Code) (s : Spelling) :
    (winb (finalWindow [lo]) s && !(winb (finalWindow [hi + 1]) s))
      = winb (rangeWindow lo hi) s :=
  winb_final_diff [lo] [hi + 1] s

/-- A reversed window is empty. -/
theorem winb_empty (lo hi s : Spelling) (hrev : shortlexLe hi lo = true) :
    winb ⟨lo, some hi⟩ s = false := by
  cases hlo : shortlexLe lo s with
  | false => simp [winb, hlo]
  | true =>
      cases hhi : shortlexLt s hi with
      | false => simp [winb, hhi]
      | true =>
          exact absurd (shortlexLe_lt_trans hrev (shortlexLe_lt_trans hlo hhi))
            (by rw [shortlexLt_irrefl]; simp)

theorem winb_range_empty (lo hi : Code) (s : Spelling) (hrev : hi < lo) :
    winb (rangeWindow lo hi) s = false := by
  refine winb_empty [lo] [hi + 1] s ?_
  exact singleton_shortlexLe (by omega)

/-- A final window's members are at least as long as its cut: shortlex never
puts a shorter spelling at or above a longer one. -/
theorem winb_final_length {lo s : Spelling} (h : winb (finalWindow lo) s = true) :
    lo.length ≤ s.length := by
  simp only [winb, finalWindow, Bool.and_true] at h
  simp only [shortlexLe, shortlexLt, Bool.or_eq_true, Bool.and_eq_true,
    decide_eq_true_eq, beq_iff_eq] at h
  rcases h with (h | ⟨h, _⟩) | rfl
  · omega
  · omega
  · exact Nat.le_refl _

/-- The range window `[ [lo], [hi+1] )` holds exactly the singletons of the
inclusive code interval: every longer spelling sits above the bound by length
dominance. -/
theorem winb_range_singleton (lo hi : Code) (s : Spelling) :
    winb (rangeWindow lo hi) s = true ↔ ∃ c, s = [c] ∧ lo ≤ c ∧ c ≤ hi := by
  simp only [winb, rangeWindow, Bool.and_eq_true]
  constructor
  · rintro ⟨hlo, hhi⟩
    match s with
    | [] => simp [shortlexLe, shortlexLt, lexLt] at hlo
    | [c] =>
        refine ⟨c, rfl, ?_⟩
        rw [singleton_shortlexLe_iff] at hlo
        rw [singleton_shortlexLt_iff] at hhi
        omega
    | c :: d :: s' => simp [shortlexLt] at hhi
  · rintro ⟨c, rfl, hlo, hhi⟩
    exact ⟨singleton_shortlexLe hlo, singleton_shortlexLt (by omega)⟩

end L1
