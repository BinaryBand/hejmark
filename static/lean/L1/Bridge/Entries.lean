/- L1 bridge: order semantics over the real syntax -- the entries enumeration.

`docs/foundation/L1.md` orders a universe's entries by `value`; the order axis
(`L1/Order/`) mechanizes each of the doc's order claims over an abstract model,
and `L1/Order/Enumeration.lean`'s header names the deferred integration: an
ordinal-valued `Universe.entries` enumeration over the real syntax of
`Syntax.lean`. This file is that integration's v1 landing, and the one place
the two axes meet -- `L1/Membership/` and `L1/Order/` stay independent of each
other.

The carrier is `Entries n`, the spellings a real `Node` denotes
(`Semantics.lean`'s `denotes`), and the enumeration is ordinal-valued by a fact
the rest of the tree never needed: Mathlib's `List.Shortlex (· < ·)` is a well
order over the membership axis's *infinite* alphabet `Spelling = List Nat` --
well-foundedness and trichotomy of `<` on `Nat` are all `List.Shortlex.wf` and
`List.Shortlex.trichotomous` ask for. What the infinite alphabet costs is type
omega, not well-orderedness (`Spelling.lean`'s header: each length class is
already infinite), so `entriesType : Node -> Ordinal` is total on every term
and the type-omega claims land as theorems about the finite fragment:

- Phase A on real syntax (`entriesType_le_omega0`, `entriesType_eq_omega0`): a
  node whose denotation stays over a finite code range wears its entries in a
  shortlex well order of type at most omega -- exactly omega when infinite.
- Phase E on real stage data (`entryLt_type_le_omega0`, `_eq_omega0`): a
  binder with finite stages enumerates first-appearance-major within the one
  limit, fed by `Semantics.lean`'s `stage` ladder through `firstStage`.
- The demotion row `{{{}}, &C}` (`unitClosure_entriesType`,
  `unitClosure_entryLt_type`, `unitClosure_entryLt_iff`): both enumerations
  have type exactly omega and the first-appearance order *is* the spelling
  order -- "the spelling order is generated, not postulated", now at the
  order level -- with `unitClosure_entryLt_iff_shortlexLt` reading the same
  fact back through the evaluator's Bool order via `shortlexLt_iff_fshortlex`.
- The admission witness `{ab, {a}&{b}}` (`anbn_entriesType`): type omega too.

`entryLt` is stage-major with the spelling order within a stage; the doc's
"body order within a stage" for general bodies (union/product body order,
collision ownership of faces) and the transfinite entry types (the product
rows at omega*k and omega^2) stay deferred -- the narrowed TODO in
`docs/.TODO.md`. -/
import L1.Membership.Laws
import L1.Membership.NorthStar
import L1.Order.Enumeration

namespace L1

open Ordinal

/- ---------------------------------------------------------------- -/
/- Shortlex is a well order over the real (infinite) alphabet.       -/
/- ---------------------------------------------------------------- -/

instance : IsWellFounded Spelling (List.Shortlex (· < ·)) :=
  ⟨List.Shortlex.wf wellFounded_lt⟩

instance : Std.Trichotomous (List.Shortlex ((· < ·) : Code → Code → Prop)) :=
  List.Shortlex.trichotomous

instance : IsWellOrder Spelling (List.Shortlex (· < ·)) where

/- ---------------------------------------------------------------- -/
/- The carrier and the two orders.                                   -/
/- ---------------------------------------------------------------- -/

/-- The entries of a real term: the spellings it denotes. The Lean shape of
the Python `Universe.entries` index set (`denotes` is `Universe.contains`;
membership is collision-invariant, so the carrier needs no ownership data). -/
abbrev Entries (n : Node) := Subtype (denotes n)

/-- The spelling (value) order on a node's entries: shortlex, restricted.
Total on every `Node`. -/
def entrySpellLt (n : Node) : Entries n → Entries n → Prop :=
  Subrel (List.Shortlex (· < ·)) (denotes n)

instance (n : Node) : IsWellOrder (Entries n) (entrySpellLt n) :=
  inferInstanceAs (IsWellOrder _ (Subrel _ _))

/-- The ordinal-valued entries enumeration, total on every `Node`: the order
type of the spelling order on its entries. -/
noncomputable def entriesType (n : Node) : Ordinal := Ordinal.type (entrySpellLt n)

/-- The least stage at which a binder wears `s` (`0` when it never does):
first appearance, read off the real stage ladder of `Semantics.lean`. -/
noncomputable def firstStage (n : Node) (s : Spelling) : ℕ := sInf {k | stage n k s}

theorem firstStage_stage (n : Node) (s : Spelling) (h : ∃ k, stage n k s) :
    stage n (firstStage n s) s :=
  Nat.sInf_mem h

theorem firstStage_le (n : Node) (s : Spelling) {k : ℕ} (h : stage n k s) :
    firstStage n s ≤ k :=
  Nat.sInf_le h

/-- The first-appearance order on a node's entries: stage-major, spelling
order within a stage. -/
def entryLt (n : Node) : Entries n → Entries n → Prop := fun a b =>
  Prod.Lex (· < ·) (List.Shortlex (· < ·)) (firstStage n a.1, a.1) (firstStage n b.1, b.1)

/-- First-appearance addresses embed into the lex order on
`(stage, spelling)` pairs -- the real-syntax face of phase E's `stageAddr`. -/
noncomputable def entryAddrEmb (n : Node) :
    entryLt n ↪r Prod.Lex ((· < ·) : ℕ → ℕ → Prop) (List.Shortlex ((· < ·) : Code → Code → Prop)) :=
  ⟨⟨fun a => (firstStage n a.1, a.1), fun _ _ h => Subtype.ext (congrArg Prod.snd h)⟩,
    Iff.rfl⟩

instance (n : Node) : IsWellOrder (Entries n) (entryLt n) :=
  (entryAddrEmb n).isWellOrder

/- ---------------------------------------------------------------- -/
/- Phase A on real syntax: a finite code range caps the spelling     -/
/- order at the one limit.                                           -/
/- ---------------------------------------------------------------- -/

/-- Boundedly many codes and bounded length is finitely many spellings: the
predecessor pool every shortlex step below a fixed spelling draws from. -/
theorem boundedSpellings_finite (m L : ℕ) :
    {s : Spelling | s.length ≤ L ∧ ∀ c ∈ s, c ≤ m}.Finite := by
  induction L with
  | zero =>
      refine (Set.finite_singleton ([] : Spelling)).subset ?_
      rintro s ⟨hlen, -⟩
      cases s with
      | nil => rfl
      | cons c rest => simp at hlen
  | succ L ih =>
      refine ((Set.finite_singleton ([] : Spelling)).union
        (Set.Finite.image2 (· :: ·) (Set.finite_Iic m) ih)).subset ?_
      rintro s ⟨hlen, hcodes⟩
      cases s with
      | nil => exact Or.inl rfl
      | cons c rest =>
          right
          refine ⟨c, hcodes c (by simp), rest, ⟨?_, fun x hx => hcodes x (by simp [hx])⟩, rfl⟩
          simp only [List.length_cons] at hlen
          omega

/-- Below a fixed entry, the spelling order draws from a finite pool: shortlex
never lengthens, and the code range is finite by hypothesis. -/
theorem entrySpellLt_finite_predecessors (n : Node) (m : ℕ)
    (hm : ∀ s, denotes n s → ∀ c ∈ s, c ≤ m) (x : Entries n) :
    {y | entrySpellLt n y x}.Finite := by
  have hsub : {y | entrySpellLt n y x} ⊆
      Subtype.val ⁻¹' {s : Spelling | s.length ≤ x.1.length ∧ ∀ c ∈ s, c ≤ m} := by
    rintro ⟨s, hs⟩ hy
    have hlt : List.Shortlex (· < ·) s x.1 := hy
    have hlen : s.length ≤ x.1.length := by
      rcases List.shortlex_def.mp hlt with h | ⟨h, -⟩
      · exact Nat.le_of_lt h
      · exact Nat.le_of_eq h
    exact ⟨hlen, hm s hs⟩
  exact ((boundedSpellings_finite m x.1.length).preimage
    Subtype.val_injective.injOn).subset hsub

/-- Phase A on real syntax: a node whose denotation stays over a finite code
range wears its entries in a shortlex well order of type at most `ω`. -/
theorem entriesType_le_omega0 (n : Node) (m : ℕ)
    (hm : ∀ s, denotes n s → ∀ c ∈ s, c ≤ m) : entriesType n ≤ ω :=
  type_le_omega0_of_finite_predecessors _ (entrySpellLt_finite_predecessors n m hm)

/-- The exact version: infinitely many entries over a finite code range spend
the limit on the nose -- the real-syntax face of `finShortlex_type_omega0`. -/
theorem entriesType_eq_omega0 (n : Node) (m : ℕ)
    (hm : ∀ s, denotes n s → ∀ c ∈ s, c ≤ m)
    (hinf : {s | denotes n s}.Infinite) : entriesType n = ω := by
  haveI : Infinite (Entries n) := Set.infinite_coe_iff.2 hinf
  exact type_eq_omega0_of_finite_predecessors _ (entrySpellLt_finite_predecessors n m hm)

/- ---------------------------------------------------------------- -/
/- Phase E on real stage data: finite stages keep first appearance   -/
/- within the one limit.                                             -/
/- ---------------------------------------------------------------- -/

/-- Below a fixed entry, the first-appearance order draws from one finite
stage: every predecessor appears no later, so it already sits at the entry's
own first stage -- the real-syntax shape of `stageMajor_finite_predecessors`. -/
theorem entryLt_finite_predecessors (n : Node) (hb : bindsb n = true)
    (hfin : ∀ k, {s | stage n k s}.Finite) (x : Entries n) :
    {y | entryLt n y x}.Finite := by
  have hsub : {y | entryLt n y x} ⊆
      Subtype.val ⁻¹' {s | stage n (firstStage n x.1) s} := by
    rintro ⟨s, hs⟩ hy
    have hy' : Prod.Lex ((· < ·) : ℕ → ℕ → Prop) (List.Shortlex (· < ·))
        (firstStage n s, s) (firstStage n x.1, x.1) := hy
    have hex : ∃ k, stage n k s := (ndenote_binder n _ s hb).mp hs
    have hle : firstStage n s ≤ firstStage n x.1 := by
      rcases Prod.lex_def.mp hy' with h | ⟨h, -⟩
      · exact Nat.le_of_lt h
      · exact Nat.le_of_eq h
    exact stage_mono_le n _ _ s hle (firstStage_stage n s hex)
  exact ((hfin _).preimage Subtype.val_injective.injOn).subset hsub

/-- Phase E on the real staged semantics: a binder whose stages are all finite
enumerates its entries within the one limit -- first-appearance order of type
at most `ω`, fed by `Semantics.lean`'s `stage` ladder rather than an abstract
stage-size function. -/
theorem entryLt_type_le_omega0 (n : Node) (hb : bindsb n = true)
    (hfin : ∀ k, {s | stage n k s}.Finite) :
    Ordinal.type (entryLt n) ≤ ω :=
  type_le_omega0_of_finite_predecessors _ (entryLt_finite_predecessors n hb hfin)

/-- The exact version: a binder with finite stages and infinitely many entries
spends the limit on the nose -- `stageMajor_type_eq_omega0`'s content with the
real stage semantics in place of the model. -/
theorem entryLt_type_eq_omega0 (n : Node) (hb : bindsb n = true)
    (hfin : ∀ k, {s | stage n k s}.Finite)
    (hinf : {s | denotes n s}.Infinite) :
    Ordinal.type (entryLt n) = ω := by
  haveI : Infinite (Entries n) := Set.infinite_coe_iff.2 hinf
  exact type_eq_omega0_of_finite_predecessors _ (entryLt_finite_predecessors n hb hfin)

/- ---------------------------------------------------------------- -/
/- The demotion row {{{}}, &C}: both enumerations at exactly omega,  -/
/- and first appearance IS the spelling order.                       -/
/- ---------------------------------------------------------------- -/

/-- Each closure pass appends one code, so stage `k` spellings are shorter
than `k`. -/
theorem unitClosure_stage_length (lo hi : Code) :
    ∀ k s, stage (unitClosure lo hi) k s → s.length < k := by
  intro k
  induction k with
  | zero => intro s h; rw [stage_zero] at h; exact h.elim
  | succ k ih =>
      intro s h
      rw [stage_succ] at h
      rcases h with h | h
      · exact Nat.lt_succ_of_lt (ih s h)
      · rw [unitClosure_walk] at h
        rcases h with rfl | ⟨p, c, rfl, hp, -, -⟩
        · simp
        · have hp' := ih p hp
          simp only [List.length_append, List.length_cons, List.length_nil]
          omega

/-- Every stage of the demotion row is finite: length below the stage index,
codes inside `[lo, hi]`. -/
theorem unitClosure_stage_finite (lo hi : Code) (k : ℕ) :
    {s | stage (unitClosure lo hi) k s}.Finite := by
  refine (boundedSpellings_finite hi k).subset ?_
  intro s hs
  exact ⟨Nat.le_of_lt (unitClosure_stage_length lo hi k s hs),
    fun c hc => (unitClosure_stage_sound lo hi k s hs c hc).2⟩

/-- A nonempty code range generates infinitely many entries: all the
`replicate n lo` for a start. -/
theorem unitClosure_entries_infinite (lo hi : Code) (h : lo ≤ hi) :
    {s | denotes (unitClosure lo hi) s}.Infinite := by
  refine Set.infinite_of_injective_forall_mem
    (f := fun n : ℕ => List.replicate n lo) ?_ ?_
  · intro a b hab
    simpa using congrArg List.length hab
  · intro n
    rw [Set.mem_setOf_eq, unitClosure_generates]
    intro c hc
    rw [List.eq_of_mem_replicate hc]
    exact ⟨Nat.le_refl lo, h⟩

/-- First appearance on the demotion row is length plus one: each pass
appends one code, seeded by the unit's empty face. -/
theorem unitClosure_firstStage (lo hi : Code) (s : Spelling)
    (h : ∀ c ∈ s, lo ≤ c ∧ c ≤ hi) :
    firstStage (unitClosure lo hi) s = s.length + 1 := by
  have hmem : stage (unitClosure lo hi) (s.length + 1) s :=
    unitClosure_stage_complete lo hi s h
  have hle : firstStage (unitClosure lo hi) s ≤ s.length + 1 :=
    firstStage_le _ _ hmem
  have hlt : s.length < firstStage (unitClosure lo hi) s :=
    unitClosure_stage_length lo hi _ s (firstStage_stage _ s ⟨_, hmem⟩)
  omega

/-- The demotion row's entries enumeration has type exactly `ω`: phase A's
`finShortlex_type_omega0`, read off the real `{{{}}, &C}` term. -/
theorem unitClosure_entriesType (lo hi : Code) (h : lo ≤ hi) :
    entriesType (unitClosure lo hi) = ω :=
  entriesType_eq_omega0 _ hi
    (fun s hs c hc => ((unitClosure_generates lo hi s).mp hs c hc).2)
    (unitClosure_entries_infinite lo hi h)

/-- Its first-appearance enumeration spends the limit exactly too: phase E's
`stageMajor_type_eq_omega0` content, fed with the real stage ladder. -/
theorem unitClosure_entryLt_type (lo hi : Code) (h : lo ≤ hi) :
    Ordinal.type (entryLt (unitClosure lo hi)) = ω :=
  entryLt_type_eq_omega0 _ (unitClosure_bindsb lo hi)
    (unitClosure_stage_finite lo hi)
    (unitClosure_entries_infinite lo hi h)

/-- "First-appearance order is value order": on the demotion row the
generated enumeration coincides with the spelling order. The doc's "the
spelling order is generated, not postulated", now at the order level --
`unitClosure_generates` is the same claim at the membership level. -/
theorem unitClosure_entryLt_iff (lo hi : Code) (a b : Entries (unitClosure lo hi)) :
    entryLt (unitClosure lo hi) a b ↔ List.Shortlex (· < ·) a.1 b.1 := by
  have hfa : firstStage (unitClosure lo hi) a.1 = a.1.length + 1 :=
    unitClosure_firstStage lo hi a.1 ((unitClosure_generates lo hi a.1).mp a.2)
  have hfb : firstStage (unitClosure lo hi) b.1 = b.1.length + 1 :=
    unitClosure_firstStage lo hi b.1 ((unitClosure_generates lo hi b.1).mp b.2)
  simp only [entryLt, Prod.lex_def, hfa, hfb]
  constructor
  · rintro (h | ⟨-, hsl⟩)
    · exact List.Shortlex.of_length_lt (by omega)
    · exact hsl
  · intro hsl
    rcases List.shortlex_def.mp hsl with h | ⟨h, -⟩
    · exact Or.inl (by omega)
    · exact Or.inr ⟨by omega, hsl⟩

/-- The same coincidence through the evaluator's Bool order: the bridge
`shortlexLt_iff_fshortlex` keeps the two shortlex theories in lockstep, so
the generated enumeration is exactly what `shortlexLt` decides. -/
theorem unitClosure_entryLt_iff_shortlexLt (lo hi : Code)
    (a b : Entries (unitClosure lo hi)) :
    entryLt (unitClosure lo hi) a b ↔ shortlexLt a.1 b.1 = true := by
  rw [unitClosure_entryLt_iff, shortlexLt_iff_fshortlex]

/- ---------------------------------------------------------------- -/
/- The admission witness {ab, {a}&{b}}: type omega as well.          -/
/- ---------------------------------------------------------------- -/

/-- The crown witness wears its entries at type exactly `ω`: `anbn_exact`
pins the denotation to the `a^n b^n`, which sit over the two-code range and
are infinitely many. -/
theorem anbn_entriesType : entriesType anbn = ω := by
  refine entriesType_eq_omega0 anbn lb ?_ ?_
  · intro s hs c hc
    obtain ⟨n, -, rfl⟩ := (anbn_exact s).mp hs
    rw [List.mem_append] at hc
    rcases hc with hc | hc
    · rw [List.eq_of_mem_replicate hc]; decide
    · rw [List.eq_of_mem_replicate hc]
  · refine Set.infinite_of_injective_forall_mem
      (f := fun n : ℕ => List.replicate (n + 1) la ++ List.replicate (n + 1) lb) ?_ ?_
    · intro a b hab
      have hlen := congrArg List.length hab
      simp at hlen
      omega
    · intro n
      rw [Set.mem_setOf_eq, anbn_exact]
      exact ⟨n + 1, by omega, rfl⟩

end L1
