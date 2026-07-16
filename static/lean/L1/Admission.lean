/- L1 re-admission test: the axioms earn their places.

Two `docs/foundation/L1.md` claims live here, both about why the constructor list is exactly what
it is.

**The universe operand is axiomatic** ("The constructors", closing paragraph): "an entry-wise step
adds or removes finitely many entries, while `{a.., !{ {a..}{b}{a..} }}` -- every spelling with no
interior `b`-seam -- needs infinitely many removals and is unreachable by any finite iteration of
entry-wise steps." Mechanized as `operand_needs_infinitely_many_removals`: finitely many entry-wise
steps (each a finite symmetric difference) reach only sets a finite symmetric difference away
(`entrySteps_finite_diff`), and the seam-free set differs from the final segment on the infinite
family `a b a^(i+1)`.

**Closure refuses by power** ("The re-admission test"): `{ab, {a}&{b}}` denotes `a^n b^n` -- "no
regular face set, so no arrangement of the others reaches it." Mechanized against the *real*
semantics: `anbn_exact` characterizes the closure's denotation exactly (a stage induction in both
directions over `NorthStar.lean`'s `anbn` node), and `closure_admission` shows that face set is not
a regular language, by Myhill-Nerode: the left quotients by `a^(i+1)` are pairwise distinct, so
they cannot fit in the finitely many states of any DFA. This is the witness half of the
re-admission test -- closure reaches past every finite-state face set, so it must stand as
axiomatic. (The complementary half, that every closure-free universe *has* a regular face set, needs a
DFA construction for shortlex windows over the code space and stays deferred with the rest of the
`Universe.entries` integration; the witness half is the load-bearing direction, since it is what
rules the compression route out.) -/
import L1.NorthStar
import Mathlib.Computability.MyhillNerode

namespace L1

/- ---------------------------------------------------------------- -/
/- The universe operand is axiomatic: finite iteration of entry-wise -/
/- steps cannot make infinitely many removals.                       -/
/- ---------------------------------------------------------------- -/

/-- One entry-wise step: finitely many spellings enter or leave. -/
def EntryStep (S T : Set Spelling) : Prop := (symmDiff S T).Finite

/-- Finitely many entry-wise steps from `S`. -/
def EntrySteps : ℕ → Set Spelling → Set Spelling → Prop
  | 0, S, T => T = S
  | n + 1, S, T => ∃ U, EntrySteps n S U ∧ EntryStep U T

/-- Any finite iteration of entry-wise steps stays a finite symmetric difference away. -/
theorem entrySteps_finite_diff : ∀ (n : ℕ) (S T : Set Spelling),
    EntrySteps n S T → (symmDiff S T).Finite
  | 0, S, T, h => by rw [h]; simp
  | n + 1, S, T, ⟨U, hU, hstep⟩ => by
      have h1 := entrySteps_finite_diff n S U hU
      exact ((h1.union hstep).subset (symmDiff_triangle S U T))

/-- `{a..}` from the least code: every nonempty spelling. -/
def finalSeg : Set Spelling := {s | s ≠ []}

/-- The subtraction's target: nonempty spellings with no interior `b`-seam. -/
def seamFree : Set Spelling :=
  {s | s ≠ [] ∧ ¬ ∃ p q, p ≠ [] ∧ q ≠ [] ∧ s = p ++ lb :: q}

/-- Headline: the seam-free set is unreachable from the final segment by any finite iteration of
entry-wise steps -- the removals `a b a^(i+1)` are infinitely many. This is why union and
subtraction take a *universe* operand axiomatically, not entry-wise steps as a derived form. -/
theorem operand_needs_infinitely_many_removals :
    ∀ n, ¬ EntrySteps n finalSeg seamFree := by
  intro n h
  have hfin := entrySteps_finite_diff n _ _ h
  have hinj : Function.Injective (fun i : ℕ => la :: lb :: List.replicate (i + 1) la) := by
    intro i j hij
    have := congrArg List.length hij
    simpa using this
  have hmem : ∀ i : ℕ, (la :: lb :: List.replicate (i + 1) la) ∈ symmDiff finalSeg seamFree := by
    intro i
    rw [Set.mem_symmDiff]
    left
    refine ⟨by simp [finalSeg], ?_⟩
    intro hsf
    refine hsf.2 ⟨[la], List.replicate (i + 1) la, by simp, ?_, by simp⟩
    intro hrep
    have := congrArg List.length hrep
    simp at this
  exact (Set.infinite_of_injective_forall_mem hinj hmem) hfin

/- ---------------------------------------------------------------- -/
/- The exact language of {ab, {a}&{b}}: a^n b^n, n >= 1.             -/
/- ---------------------------------------------------------------- -/

/-- Appending one more copy is the same as prepending it: the snoc form of `replicate`. -/
theorem replicate_snoc (n : ℕ) (a : Code) :
    List.replicate n a ++ [a] = a :: List.replicate n a := by
  rw [← List.replicate_succ', List.replicate_succ]

/-- Every stage member is some `a^n b^n`, `1 ≤ n` -- the forward half of exactness, by the same
stage induction as `anbn_stage_even` but carrying the full witness. -/
theorem anbn_stage_exact : ∀ k s, stage anbn k s →
    ∃ n, 1 ≤ n ∧ s = List.replicate n la ++ List.replicate n lb := by
  intro k
  induction k with
  | zero => intro s h; rw [stage_zero] at h; exact h.elim
  | succ k ih =>
      intro s h
      rw [stage_succ] at h
      rcases h with h | h
      · exact ih s h
      · simp only [anbn, nlist, walk_cons, walk_single_prod, walk_single_face,
          walk_nil] at h
        rcases h with (h | h) | h
        · exact h.elim
        · exact ⟨1, le_refl 1, by simp [h]⟩
        · simp only [fsplit_fnode] at h
          obtain ⟨p, q, rfl, hp, hq⟩ := h
          rw [ndenote_nonbinder _ _ _ (by decide), walk_cons, walk_single_face,
            walk_nil] at hp
          rcases hp with hp | rfl
          · exact hp.elim
          rw [fsplit_famp] at hq
          obtain ⟨p2, q2, rfl, hamp, hq2⟩ := hq
          simp only [fsplit_fnode, fsplit_fnil] at hq2
          obtain ⟨p3, q3, rfl, hp3, rfl⟩ := hq2
          rw [ndenote_nonbinder _ _ _ (by decide), walk_cons, walk_single_face,
            walk_nil] at hp3
          rcases hp3 with hp3 | rfl
          · exact hp3.elim
          obtain ⟨n, hn, rfl⟩ := ih p2 hamp
          refine ⟨n + 1, by omega, ?_⟩
          simp [List.replicate_succ, replicate_snoc, List.append_assoc]

/-- Every `a^n b^n` appears by stage `n` -- the backward half, building the walk stage by stage. -/
theorem anbn_stage_build : ∀ n, 1 ≤ n →
    stage anbn n (List.replicate n la ++ List.replicate n lb) := by
  intro n
  induction n with
  | zero => omega
  | succ n ih =>
      intro _
      rw [stage_succ]
      right
      simp only [anbn, nlist, walk_cons, walk_single_prod, walk_single_face, walk_nil]
      rcases Nat.eq_or_lt_of_le (Nat.zero_le n) with hn0 | hn1
      · -- n = 0: the base face `ab` itself.
        left
        right
        simp [← hn0]
      · -- n ≥ 1: split as `a · (a^n b^n) · b` with the middle at the previous stage.
        right
        rw [fsplit_fnode]
        refine ⟨[la], List.replicate n la ++ List.replicate n lb ++ [lb], ?_, ?_, ?_⟩
        · simp [List.replicate_succ, replicate_snoc, List.append_assoc]
        · rw [ndenote_nonbinder _ _ _ (by decide), walk_cons, walk_single_face, walk_nil]
          exact Or.inr rfl
        · rw [fsplit_famp]
          refine ⟨List.replicate n la ++ List.replicate n lb, [lb], by simp, ih hn1, ?_⟩
          rw [fsplit_fnode]
          refine ⟨[lb], [], by simp, ?_, by rw [fsplit_fnil]⟩
          rw [ndenote_nonbinder _ _ _ (by decide), walk_cons, walk_single_face, walk_nil]
          exact Or.inr rfl

/-- The exact language of the admission witness: `{ab, {a}&{b}}` denotes precisely
`a^n b^n`, `n ≥ 1` -- both directions, against the real staged semantics. -/
theorem anbn_exact (s : Spelling) :
    denotes anbn s ↔ ∃ n, 1 ≤ n ∧ s = List.replicate n la ++ List.replicate n lb := by
  rw [denotes, ndenote_binder _ _ _ (by decide)]
  constructor
  · rintro ⟨k, hk⟩
    exact anbn_stage_exact k s hk
  · rintro ⟨n, hn, rfl⟩
    exact ⟨n, anbn_stage_build n hn⟩

/- ---------------------------------------------------------------- -/
/- a^n b^n is not regular: Myhill-Nerode over the left quotients.    -/
/- ---------------------------------------------------------------- -/

/-- The witness language, as a `Language` over the code space. -/
def anbnLang : Language Code :=
  {s | ∃ n, 1 ≤ n ∧ s = List.replicate n la ++ List.replicate n lb}

/-- `a^p b^q` matches `a^n b^n` only on the nose: counting `a`s pins `p`, the length pins `q`. -/
theorem rep_rep_inj {p q n : ℕ}
    (h : List.replicate p la ++ List.replicate q lb
       = List.replicate n la ++ List.replicate n lb) : p = n ∧ q = n := by
  have hc := congrArg (List.count la) h
  have hl := congrArg List.length h
  simp [List.count_append, List.count_replicate] at hc hl
  omega

/-- The left quotients by `a^(i+1)` are pairwise distinct: `b^(i+1)` completes exactly one of
them. Infinitely many distinct quotients is Myhill-Nerode's witness of non-regularity. -/
theorem anbnLang_leftQuotient_injective :
    Function.Injective (fun i : ℕ => anbnLang.leftQuotient (List.replicate (i + 1) la)) := by
  intro i j hij
  have hij' : anbnLang.leftQuotient (List.replicate (i + 1) la)
      = anbnLang.leftQuotient (List.replicate (j + 1) la) := hij
  have hi : List.replicate (i + 1) lb ∈ anbnLang.leftQuotient (List.replicate (i + 1) la) :=
    ⟨i + 1, by omega, rfl⟩
  rw [hij'] at hi
  have hmem : List.replicate (j + 1) la ++ List.replicate (i + 1) lb ∈ anbnLang := hi
  obtain ⟨n, _, hn⟩ := hmem
  obtain ⟨h1, h2⟩ := rep_rep_inj hn
  omega

/-- `a^n b^n` is not a regular language. -/
theorem anbnLang_not_regular : ¬ anbnLang.IsRegular := by
  intro hreg
  have hfin := hreg.finite_range_leftQuotient
  have hmem : ∀ i : ℕ, anbnLang.leftQuotient (List.replicate (i + 1) la) ∈
      Set.range anbnLang.leftQuotient :=
    fun i => ⟨List.replicate (i + 1) la, rfl⟩
  exact Set.infinite_of_injective_forall_mem anbnLang_leftQuotient_injective hmem hfin

/-- Headline (closure's admission witness): the face set `{ab, {a}&{b}}` denotes is not regular,
so closure reaches past every finite-state face set -- "no arrangement of the others reaches it,"
and closure keeps its axiomatic place on the constructor list. -/
theorem closure_admission : ¬ Language.IsRegular ({s | denotes anbn s} : Language Code) := by
  have hL : ({s | denotes anbn s} : Language Code) = anbnLang := by
    ext s
    exact anbn_exact s
  rw [hL]
  exact anbnLang_not_regular

end L1
