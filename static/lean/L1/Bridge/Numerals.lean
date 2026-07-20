/- The canonical-numerals north-star row, on real syntax: value order is spelling order is
first-appearance order on `{0, {1..9, &{0..9}}}`.

`docs/foundation/L1.md` (Canonical numerals): "First-appearance order under the numerals closure
is therefore value order (the north-star row below), so the value line of a character radix
arrives shortlex-sorted and a spelling range cuts it exactly -- the read L1.5's `where` leans on."
`L1/Order/Numerals.lean` proves the abstract half (shortlex is positional-value order on the
canonical numerals of a sub-range head radix); this file lands the same claim on the real
north-star term with `Semantics.lean`'s stage ladder supplying first appearance.

Which node carries which statement. `NorthStar.lean`'s `numerals` is a *non-binder*: its `&` is
hidden inside the fold, so the full term's own stage ladder has a single rung
(`numerals_firstStage`) and its first-appearance order is degenerately the spelling order. The
genuine first-appearance content lives on `numerals_body = {1..9, &{0..9}}`, the binder the fold
braces: stage `k` holds exactly the nonzero-headed numerals of width at most `k`
(`numerals_body_stage_sound`/`_complete`), so first appearance is width
(`numerals_body_firstStage`) and the stage-major order collapses onto shortlex
(`numerals_body_entryLt_iff`) -- the demotion row's argument (`unitClosure_entryLt_iff`) with the
sub-range seed `{1..9}` in place of the empty-spelling unit. The value map `numVal` then reads
each entry as a decimal numeral, and both orders agree with value order
(`numerals_body_entryLt_iff_numVal_lt`, `numerals_entrySpellLt_iff_numVal_lt`): the doc's
sentence, with the zero face priced in on the full term. -/
import L1.Bridge.Rows
import L1.Membership.Settling

namespace L1

open Ordinal

/- ---------------------------------------------------------------- -/
/- Layer 1: what the term denotes. The closure generates exactly     -/
/- the nonzero-headed digit strings, width by width.                 -/
/- ---------------------------------------------------------------- -/

/-- A nonzero-headed numeral: a digit spelling led from the sub-range `{1..9}`, continued from
the full `{0..9}` -- the closure half of the canonical numerals. -/
def NZNumeral (s : Spelling) : Prop :=
  ∃ c r, s = c :: r ∧ d1 ≤ c ∧ c ≤ d9 ∧ ∀ x ∈ r, d0 ≤ x ∧ x ≤ d9

/-- A canonical numeral: the zero digit, or a nonzero-headed numeral. -/
def CanonNumeral (s : Spelling) : Prop := s = [d0] ∨ NZNumeral s

theorem NZNumeral.codes {s : Spelling} (h : NZNumeral s) : ∀ c ∈ s, d0 ≤ c ∧ c ≤ d9 := by
  obtain ⟨c, r, rfl, h1, h2, h3⟩ := h
  intro x hx
  rcases List.mem_cons.mp hx with rfl | hx
  · refine ⟨?_, h2⟩
    have hd : d0 ≤ d1 := by decide
    omega
  · exact h3 x hx

theorem NZNumeral.not_zero {s : Spelling} (h : NZNumeral s) : s ≠ [d0] := by
  obtain ⟨c, r, rfl, h1, -, -⟩ := h
  intro hcontra
  simp only [List.cons.injEq] at hcontra
  obtain ⟨rfl, -⟩ := hcontra
  exact absurd h1 (by decide)

theorem CanonNumeral.codes {s : Spelling} (h : CanonNumeral s) :
    ∀ c ∈ s, d0 ≤ c ∧ c ≤ d9 := by
  rcases h with rfl | h
  · intro c hc
    rcases List.mem_singleton.mp hc with rfl
    exact ⟨Nat.le_refl d0, by decide⟩
  · exact h.codes

theorem numerals_body_bindsb : bindsb numerals_body = true := by decide

/-- One closure pass of the numerals body: a seed digit from the sub-range `{1..9}`, or an
ambient spelling extended by one full-range digit on the right. -/
theorem numerals_body_walk (amp : Spelling → Prop) (s : Spelling) :
    walk numerals_body amp False s
      ↔ (∃ c, s = [c] ∧ d1 ≤ c ∧ c ≤ d9)
        ∨ ∃ p c, s = p ++ [c] ∧ amp p ∧ d0 ≤ c ∧ c ≤ d9 := by
  simp only [numerals_body, nlist, walk_cons, walk_single_range, walk_single_prod,
    walk_nil, false_or]
  constructor
  · rintro (h | h)
    · left
      rw [winb_range_singleton] at h
      exact h
    · right
      rw [fsplit_famp] at h
      obtain ⟨p, q, rfl, hp, hq⟩ := h
      rw [fsplit_fnode] at hq
      obtain ⟨p2, q2, rfl, hp2, hq2⟩ := hq
      rw [fsplit_fnil] at hq2
      subst hq2
      rw [ndenote_nonbinder _ _ _ (by decide), walk_cons, walk_nil,
        walk_single_range] at hp2
      rcases hp2 with h' | h'
      · exact h'.elim
      · rw [winb_range_singleton] at h'
        obtain ⟨c, rfl, hc1, hc2⟩ := h'
        exact ⟨p, c, by simp, hp, hc1, hc2⟩
  · rintro (⟨c, rfl, hc1, hc2⟩ | ⟨p, c, rfl, hp, hc1, hc2⟩)
    · left
      rw [winb_range_singleton]
      exact ⟨c, rfl, hc1, hc2⟩
    · right
      rw [fsplit_famp]
      refine ⟨p, [c], rfl, hp, ?_⟩
      rw [fsplit_fnode]
      refine ⟨[c], [], by simp, ?_, by rw [fsplit_fnil]⟩
      rw [ndenote_nonbinder _ _ _ (by decide), walk_cons, walk_nil, walk_single_range]
      right
      rw [winb_range_singleton]
      exact ⟨c, rfl, hc1, hc2⟩

/-- Soundness: every closure stage holds only nonzero-headed numerals -- the seed is the
sub-range and a pass never touches the head. Subsumes `numerals_body_headed`. -/
theorem numerals_body_stage_sound :
    ∀ k s, stage numerals_body k s → NZNumeral s :=
  stage_invariant _ NZNumeral fun _ ih s h => by
    rw [numerals_body_walk] at h
    rcases h with ⟨c, rfl, hc1, hc2⟩ | ⟨p, c, rfl, hp, hc1, hc2⟩
    · exact ⟨c, [], rfl, hc1, hc2, by simp⟩
    · obtain ⟨c0, r0, rfl, h1, h2, h3⟩ := ih p hp
      refine ⟨c0, r0 ++ [c], by simp, h1, h2, ?_⟩
      intro x hx
      rcases List.mem_append.mp hx with hx | hx
      · exact h3 x hx
      · rcases List.mem_singleton.mp hx with rfl
        exact ⟨hc1, hc2⟩

/-- Each pass appends one digit and the seed is already one digit wide, so stage `k` spellings
are at most `k` wide -- `≤ k`, not `< k`: unlike the demotion row there is no empty seed. -/
theorem numerals_body_stage_length :
    ∀ k s, stage numerals_body k s → s.length ≤ k := by
  intro k
  induction k with
  | zero => intro s h; rw [stage_zero] at h; exact h.elim
  | succ k ih =>
      intro s h
      rw [stage_succ] at h
      rcases h with h | h
      · exact Nat.le_succ_of_le (ih s h)
      · rw [numerals_body_walk] at h
        rcases h with ⟨c, rfl, -, -⟩ | ⟨p, c, rfl, hp, -, -⟩
        · simp
        · have := ih p hp
          simp only [List.length_append, List.length_cons, List.length_nil]
          omega

/-- Completeness: a nonzero-headed numeral of width `L` is present by stage `L` -- the head digit
seeds at stage one, each later digit costs one pass. -/
theorem numerals_body_stage_complete :
    ∀ s : Spelling, NZNumeral s → stage numerals_body s.length s := by
  intro s
  induction s using List.reverseRecOn with
  | nil =>
      rintro ⟨c0, r0, heq, -, -, -⟩
      simp at heq
  | append_singleton p c ih =>
      rintro ⟨c0, r0, heq, h1, h2, h3⟩
      have hlen : (p ++ [c]).length = p.length + 1 := by simp
      rw [hlen, stage_succ]
      right
      rw [numerals_body_walk]
      cases p with
      | nil =>
          simp only [List.nil_append, List.cons.injEq] at heq
          obtain ⟨rfl, rfl⟩ := heq
          exact Or.inl ⟨c, by simp, h1, h2⟩
      | cons ph pt =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, hr0⟩ := heq
          subst hr0
          have hc : d0 ≤ c ∧ c ≤ d9 := h3 c (by simp)
          have hp : NZNumeral (ph :: pt) :=
            ⟨ph, pt, rfl, h1, h2, fun x hx => h3 x (by simp [hx])⟩
          exact Or.inr ⟨ph :: pt, c, rfl, ih hp, hc.1, hc.2⟩

/-- The closure half, two-sided: the braced body denotes exactly the nonzero-headed numerals.
The membership face of "the value line is generated". -/
theorem numerals_body_generates (s : Spelling) :
    denotes numerals_body s ↔ NZNumeral s := by
  rw [denotes, ndenote_binder _ _ _ numerals_body_bindsb]
  constructor
  · rintro ⟨k, hk⟩
    exact numerals_body_stage_sound k s hk
  · intro h
    exact ⟨s.length, numerals_body_stage_complete s h⟩

/-- The north-star row, two-sided: `{0, {1..9, &{0..9}}}` denotes exactly the canonical
numerals. `numerals_not_01`'s "a leading zero never appears", upgraded to the full inventory. -/
theorem numerals_generates (s : Spelling) :
    denotes numerals s ↔ CanonNumeral s := by
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)]
  simp only [numerals, nlist, walk_cons, walk_single_face, walk_single_fold, walk_nil,
    false_or]
  rw [spells_fold_binder _ _ _ numerals_body_bindsb]
  constructor
  · rintro (h | ⟨k, hk⟩)
    · exact Or.inl h
    · exact Or.inr (numerals_body_stage_sound k s hk)
  · rintro (rfl | h)
    · exact Or.inl rfl
    · exact Or.inr ⟨s.length, numerals_body_stage_complete s h⟩

/- ---------------------------------------------------------------- -/
/- Layer 2: enumeration. First appearance is width, the stage-major -/
/- order collapses onto shortlex, and both agree with the value.     -/
/- ---------------------------------------------------------------- -/

/-- First appearance on the numerals closure is width: the head digit seeds at stage one and
each later digit costs one pass. The demotion row's `length + 1` without the empty seed. -/
theorem numerals_body_firstStage (s : Spelling) (h : NZNumeral s) :
    firstStage numerals_body s = s.length := by
  have hmem : stage numerals_body s.length s := numerals_body_stage_complete s h
  have hle : firstStage numerals_body s ≤ s.length := firstStage_le _ _ hmem
  have hge : s.length ≤ firstStage numerals_body s :=
    numerals_body_stage_length _ s (firstStage_stage _ s ⟨_, hmem⟩)
  omega

/-- Every stage is finite: width at most the stage index, codes inside the digit range. -/
theorem numerals_body_stage_finite (k : ℕ) :
    {s | stage numerals_body k s}.Finite := by
  refine (boundedSpellings_finite d9 k).subset ?_
  intro s hs
  exact ⟨numerals_body_stage_length k s hs,
    fun c hc => ((numerals_body_stage_sound k s hs).codes c hc).2⟩

theorem numerals_body_entries_infinite : {s | denotes numerals_body s}.Infinite := by
  refine Set.infinite_of_injective_forall_mem
    (f := fun n : ℕ => d1 :: List.replicate n d1) ?_ ?_
  · intro a b hab
    simpa using congrArg List.length hab
  · intro n
    rw [Set.mem_setOf_eq, numerals_body_generates]
    refine ⟨d1, List.replicate n d1, rfl, Nat.le_refl d1, by decide, ?_⟩
    intro x hx
    rw [List.eq_of_mem_replicate hx]
    exact ⟨by decide, by decide⟩

/-- The closure's spelling enumeration has type exactly `ω`. -/
theorem numerals_body_entriesType : entriesType numerals_body = ω :=
  entriesType_eq_omega0 _ d9
    (fun s hs c hc => (((numerals_body_generates s).mp hs).codes c hc).2)
    numerals_body_entries_infinite

/-- Its first-appearance enumeration spends the limit exactly too: phase E's
`stageMajor_type_eq_omega0` content, fed with the real stage ladder of the numerals body. -/
theorem numerals_body_entryLt_type : Ordinal.type (entryLt numerals_body) = ω :=
  entryLt_type_eq_omega0 _ numerals_body_bindsb numerals_body_stage_finite
    numerals_body_entries_infinite

/-- First-appearance order under the numerals closure is the spelling order: first appearance
is width, and within a width the tie-break is shortlex's own -- the demotion row's collapse
(`unitClosure_entryLt_iff`), now with the sub-range seed. -/
theorem numerals_body_entryLt_iff (a b : Entries numerals_body) :
    entryLt numerals_body a b ↔ List.Shortlex (· < ·) a.1 b.1 := by
  have hfa : firstStage numerals_body a.1 = a.1.length :=
    numerals_body_firstStage a.1 ((numerals_body_generates a.1).mp a.2)
  have hfb : firstStage numerals_body b.1 = b.1.length :=
    numerals_body_firstStage b.1 ((numerals_body_generates b.1).mp b.2)
  simp only [entryLt, Prod.lex_def, hfa, hfb]
  constructor
  · rintro (h | ⟨-, hsl⟩)
    · exact List.Shortlex.of_length_lt h
    · exact hsl
  · intro hsl
    rcases List.shortlex_def.mp hsl with h | ⟨h, -⟩
    · exact Or.inl h
    · exact Or.inr ⟨h, hsl⟩

/-- The same coincidence through the evaluator's Bool order. -/
theorem numerals_body_entryLt_iff_shortlexLt (a b : Entries numerals_body) :
    entryLt numerals_body a b ↔ shortlexLt a.1 b.1 = true := by
  rw [numerals_body_entryLt_iff, shortlexLt_iff_fshortlex]

/- ---------------------------------------------------------------- -/
/- The value map: each entry read as the decimal numeral it spells.  -/
/- ---------------------------------------------------------------- -/

/-- The value a digit spelling denotes: its codes read as decimal digits, most significant
first -- `lexIndex`'s reading with the digit range translated onto `{d0..d9}`. -/
def numVal : Spelling → ℕ
  | [] => 0
  | c :: r => (c - d0) * 10 ^ r.length + numVal r

theorem numVal_lt_pow {s : Spelling} (h : ∀ c ∈ s, c ≤ d9) :
    numVal s < 10 ^ s.length := by
  induction s with
  | nil => simp [numVal]
  | cons c r ih =>
      have hc : c ≤ d9 := h c (by simp)
      have hr := ih (fun x hx => h x (by simp [hx]))
      have h09 : d9 = d0 + 9 := by decide
      have hd : c - d0 ≤ 9 := by omega
      have hmul : (c - d0) * 10 ^ r.length ≤ 9 * 10 ^ r.length :=
        Nat.mul_le_mul_right _ hd
      have hexpand : 10 * 10 ^ r.length = 9 * 10 ^ r.length + 10 ^ r.length := by ring
      simp only [numVal, List.length_cons, pow_succ']
      omega

/-- The no-leading-zero lower bound on real digits: `pow_le_lexIndex`'s content. -/
theorem pow_le_numVal {c : Code} {r : List Code} (h : d1 ≤ c) :
    10 ^ r.length ≤ numVal (c :: r) := by
  have h01 : d1 = d0 + 1 := by decide
  have hmul : 10 ^ r.length ≤ (c - d0) * 10 ^ r.length :=
    Nat.le_mul_of_pos_left _ (by omega)
  simp only [numVal]
  omega

/-- Same-width case: digit-by-digit order is value order -- `lexIndex_lt_of_lex` on real
digits. -/
theorem numVal_lt_of_lex {s t : Spelling} (hlex : List.Lex (· < ·) s t) :
    s.length = t.length → (∀ c ∈ s, d0 ≤ c ∧ c ≤ d9) → numVal s < numVal t := by
  induction hlex with
  | nil => intro hlen _; simp at hlen
  | @rel a l1 b l2 hab =>
      intro hlen hs
      simp only [List.length_cons, Nat.add_right_cancel_iff] at hlen
      have ha : d0 ≤ a ∧ a ≤ d9 := hs a (by simp)
      have hrest : numVal l1 < 10 ^ l1.length :=
        numVal_lt_pow (fun x hx => (hs x (by simp [hx])).2)
      have hab' : a - d0 + 1 ≤ b - d0 := by omega
      have hmul : (a - d0 + 1) * 10 ^ l1.length ≤ (b - d0) * 10 ^ l1.length :=
        Nat.mul_le_mul_right _ hab'
      have hexpand : (a - d0 + 1) * 10 ^ l1.length
          = (a - d0) * 10 ^ l1.length + 10 ^ l1.length := by ring
      simp only [numVal]
      rw [← hlen]
      omega
  | @cons a l1 l2 _ ih =>
      intro hlen hs
      simp only [List.length_cons, Nat.add_right_cancel_iff] at hlen
      have := ih hlen (fun x hx => hs x (by simp [hx]))
      simp only [numVal, hlen]
      omega

/-- `numVal` is strictly monotone along shortlex on the canonical numerals: cross-width by the
no-leading-zero bound, within a width digit by digit. -/
theorem canon_numVal_strictMono {s t : Spelling} (hs : CanonNumeral s) (ht : CanonNumeral t)
    (h : List.Shortlex (· < ·) s t) : numVal s < numVal t := by
  rcases List.shortlex_def.mp h with hlt | ⟨heq, hlex⟩
  · have hslen : 1 ≤ s.length := by
      rcases hs with rfl | ⟨c, r, rfl, -⟩ <;> simp
    rcases ht with rfl | ⟨c, r, rfl, h1, -, -⟩
    · simp only [List.length_singleton] at hlt
      omega
    · calc numVal s < 10 ^ s.length := numVal_lt_pow (fun c hc => (hs.codes c hc).2)
        _ ≤ 10 ^ r.length := by
            refine Nat.pow_le_pow_right (by omega) ?_
            simp only [List.length_cons] at hlt
            omega
        _ ≤ numVal (c :: r) := pow_le_numVal h1
  · exact numVal_lt_of_lex hlex heq hs.codes

/-- The doc's canonical-numerals theorem on real digits: value order and spelling order agree
on the canonical numerals. `numeral_fshortlex_iff_lexIndex_lt` read over `{d0..d9}`. -/
theorem canon_shortlex_iff_numVal_lt {s t : Spelling}
    (hs : CanonNumeral s) (ht : CanonNumeral t) :
    List.Shortlex (· < ·) s t ↔ numVal s < numVal t := by
  constructor
  · exact canon_numVal_strictMono hs ht
  · intro hv
    rcases trichotomous_of (List.Shortlex (· < ·) : Spelling → Spelling → Prop) s t
      with h | h | h
    · exact h
    · subst h; omega
    · have := canon_numVal_strictMono ht hs h
      omega

/-- The doc's sentence, on the real stage ladder: "first-appearance order under the numerals
closure is therefore value order". -/
theorem numerals_body_entryLt_iff_numVal_lt (a b : Entries numerals_body) :
    entryLt numerals_body a b ↔ numVal a.1 < numVal b.1 := by
  rw [numerals_body_entryLt_iff]
  exact canon_shortlex_iff_numVal_lt
    (Or.inr ((numerals_body_generates a.1).mp a.2))
    (Or.inr ((numerals_body_generates b.1).mp b.2))

theorem numerals_entries_infinite : {s | denotes numerals s}.Infinite := by
  refine Set.infinite_of_injective_forall_mem
    (f := fun n : ℕ => d1 :: List.replicate n d1) ?_ ?_
  · intro a b hab
    simpa using congrArg List.length hab
  · intro n
    rw [Set.mem_setOf_eq, numerals_generates]
    refine Or.inr ⟨d1, List.replicate n d1, rfl, Nat.le_refl d1, by decide, ?_⟩
    intro x hx
    rw [List.eq_of_mem_replicate hx]
    exact ⟨by decide, by decide⟩

/-- The full term: the value line of the character radix arrives in spelling order at value
order -- the zero face included. This is the order the value line is *read* in, so it is the
statement L1.5's `where` leans on. -/
theorem numerals_entrySpellLt_iff_numVal_lt (a b : Entries numerals) :
    entrySpellLt numerals a b ↔ numVal a.1 < numVal b.1 :=
  canon_shortlex_iff_numVal_lt
    ((numerals_generates a.1).mp a.2) ((numerals_generates b.1).mp b.2)

/-- The full term's spelling enumeration has type exactly `ω`: the whole value line fits in
the one limit. -/
theorem numerals_entriesType : entriesType numerals = ω :=
  entriesType_eq_omega0 _ d9
    (fun s hs c hc => (((numerals_generates s).mp hs).codes c hc).2)
    numerals_entries_infinite

/- ---------------------------------------------------------------- -/
/- The full term's own ladder is one rung: `numerals` is a           -/
/- non-binder, so its first-appearance order is degenerately the     -/
/- spelling order. The genuine first-appearance content is the       -/
/- body's, above.                                                    -/
/- ---------------------------------------------------------------- -/

theorem numerals_stage_one (s : Spelling) :
    stage numerals 1 s ↔ denotes numerals s := by
  rw [show (1 : ℕ) = 0 + 1 from rfl, stage_succ, stage_zero]
  simp only [false_or]
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)]
  exact walk_amp_irrel numerals (by decide) _ _ _ _

theorem numerals_firstStage (s : Spelling) (h : denotes numerals s) :
    firstStage numerals s = 1 := by
  have h1 : stage numerals 1 s := (numerals_stage_one s).mpr h
  have hle : firstStage numerals s ≤ 1 := firstStage_le _ _ h1
  have hne : firstStage numerals s ≠ 0 := by
    intro h0
    have hst := firstStage_stage numerals s ⟨1, h1⟩
    rw [h0, stage_zero] at hst
    exact hst
  omega

theorem numerals_entryLt_iff (a b : Entries numerals) :
    entryLt numerals a b ↔ List.Shortlex (· < ·) a.1 b.1 := by
  simp only [entryLt, Prod.lex_def, numerals_firstStage a.1 a.2,
    numerals_firstStage b.1 b.2]
  constructor
  · rintro (h | ⟨-, hsl⟩)
    · exact absurd h (lt_irrefl 1)
    · exact hsl
  · intro hsl
    exact Or.inr ⟨trivial, hsl⟩

/- ---------------------------------------------------------------- -/
/- Layer 3: the row under the shipped recursive order. The zero      -/
/- face contributes its one entry, the braced closure its omega,     -/
/- and one entry before a limit is absorbed.                         -/
/- ---------------------------------------------------------------- -/

theorem numerals_body_nSubfree : nSubfree numerals_body = true := by decide

/-- The numerals closure on the recursive enumeration: exactly `ω`. -/
theorem numerals_body_entryRecType : entryRecType numerals_body = ω :=
  entryRecType_eq_omega0 _ numerals_body_bindsb numerals_body_nSubfree
    numerals_body_stage_finite numerals_body_entries_infinite

theorem numerals_eq_napp :
    numerals = napp (nsingle (.face [d0])) (braced numerals_body) := rfl

/-- The full north-star row under the recursive order: the value line enumerates at exactly
`ω` -- the zero face's single entry, then the closure's limit, absorbed. -/
theorem numerals_entryRecType : entryRecType numerals = ω := by
  have hdisj : ∀ s, denotes (nsingle (.face [d0])) s →
      ¬ denotes (braced numerals_body) s := by
    intro s hs hbody
    rw [face_denotes_iff] at hs
    subst hs
    rw [braced_denotes_iff _ numerals_body_bindsb, numerals_body_generates] at hbody
    exact hbody.not_zero rfl
  have hbr : entryRecType (braced numerals_body) = entryRecType numerals_body :=
    entryRecType_fold_binder numerals_body numerals_body_bindsb numerals_body_nSubfree
  rw [numerals_eq_napp,
    entryRecType_napp_disjoint _ _ (by decide) (braced_bindsb _) (by decide) (by decide)
      hdisj,
    face_entryRecType, hbr, numerals_body_entryRecType, Ordinal.one_add_omega0]

end L1
