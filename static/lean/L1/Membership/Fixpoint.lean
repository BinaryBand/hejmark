/- L1 fixpoint on positive bodies: closure at omega earns its old least-fixpoint name.

`docs/foundation/L1.md` ("Fixpoint on settled bodies"): "Call an occurrence of `&` positive when no
subtraction operand encloses it ... A positive body's closure is its least fixpoint: every
constructor is continuous in a positive slot, so the inflationary stages and the bare ones agree."
`Settling.lean` mechanized the *guarded* half of that theorem (the length-bounded settling stage);
this file mechanizes the *positive* half.

Positivity is a syntactic condition on the walk spine: the only negative ambient-amp read in the
semantics is a subtraction operand (`walk op amp` under a negation), so a body is positive exactly
when every subtraction member's operand is `&`-free (`bindsb op = false` -- then `walk_amp_irrel`
makes the operand blind to the amp). Every other read is positive or independent: a bare `&` member
and an `&` factor read the amp directly, a product's node factors are amp-independent
(`ndenote_amp_indep`), and a fold always captures its own `&` (`freeAmpb (.fold _) = false`).

Three layers:

- monotonicity (`walk_amp_mono`): a positive walk is monotone in the amp (and in the accumulator,
  threaded the same way `walk_mono` threads it).
- continuity (`walk_amp_cont`): a positive walk over the union of a chain of amps is a walk over
  some single element of the chain -- the doc's "every constructor is continuous in a positive
  slot". The proof is finite-branching: each split and each `&` read picks a chain index, and the
  chain's monotonicity lets one index dominate them all. The accumulator is generalized to a chain
  of propositions threaded alongside, because the walk stores the already-processed members there.
- the fixpoint: `positive_fixpoint` (one more application of the body adds nothing:
  `walk n (closureD n) False s <-> closureD n s`), `positive_least` (any prefixpoint of the body
  contains the closure), and `bare_stages_agree` (the inflationary stages
  `X_{k+1} = X_k union body(X_k)` and the bare ones `Y_{k+1} = body(Y_k)` have the same union). -/
import L1.Membership.Settling

namespace L1

/- ---------------------------------------------------------------- -/
/- Positivity: no subtraction operand encloses an ambient `&`.       -/
/- ---------------------------------------------------------------- -/

/-- A positive member list: every subtraction operand is `&`-free. This is the doc's "no
subtraction operand encloses it", read off the walk spine -- deeper occurrences are either captured
by their own binder or amp-independent, so the spine is the only place negativity can enter. -/
def positiveb : Node → Bool
  | .nil => true
  | .cons (.sub op) rest => !(bindsb op) && positiveb rest
  | .cons _ rest => positiveb rest

/-- The closure denotation at omega: membership at some stage. -/
def closureD (n : Node) (s : Spelling) : Prop := ∃ k, stage n k s

theorem stage_chain (n : Node) : ∀ k j, k ≤ j → ∀ t, stage n k t → stage n j t :=
  fun k j hkj t => stage_mono_le n k j t hkj

/- ---------------------------------------------------------------- -/
/- Layer 1: a positive walk is monotone in the amp.                  -/
/- ---------------------------------------------------------------- -/

/-- A factor split is monotone in the amp outright: `&` factors read it positively and node
factors are amp-independent. No positivity condition is needed at the factor level. -/
theorem fsplit_amp_mono : ∀ (fs : Factors) (amp amp' : Spelling → Prop),
    (∀ t, amp t → amp' t) → ∀ s, fsplit fs amp s → fsplit fs amp' s
  | .nil, _, _, _, s => by
      rw [fsplit_fnil, fsplit_fnil]; exact id
  | .amp rest, amp, amp', h, s => by
      rw [fsplit_famp, fsplit_famp]
      rintro ⟨p, q, rfl, hp, hq⟩
      exact ⟨p, q, rfl, h p hp, fsplit_amp_mono rest amp amp' h q hq⟩
  | .node n rest, amp, amp', h, s => by
      rw [fsplit_fnode, fsplit_fnode]
      rintro ⟨p, q, rfl, hp, hq⟩
      exact ⟨p, q, rfl, (ndenote_amp_indep n amp amp' p).mp hp,
        fsplit_amp_mono rest amp amp' h q hq⟩

/-- Monotonicity in the amp (and the accumulator) for a positive walk. -/
theorem walk_amp_mono : ∀ (n : Node), positiveb n = true →
    ∀ (amp amp' : Spelling → Prop), (∀ t, amp t → amp' t) →
    ∀ (P Q : Prop), (P → Q) → ∀ s, walk n amp P s → walk n amp' Q s
  | .nil, _, _, _, _, P, Q, hpq, s, h => by
      simp only [walk] at h ⊢
      exact hpq h
  | .cons m rest, hpos, amp, amp', hamp, P, Q, hpq, s, h => by
      rw [walk_cons] at h ⊢
      cases m with
      | sub op =>
          simp only [positiveb, Bool.and_eq_true, Bool.not_eq_true'] at hpos
          refine walk_amp_mono rest hpos.2 amp amp' hamp _ _ ?_ s h
          rw [walk_single_sub, walk_single_sub]
          rintro ⟨hP, hnw⟩
          exact ⟨hpq hP, fun hw => hnw ((walk_amp_irrel op hpos.1 amp amp' False s).mpr hw)⟩
      | amp =>
          simp only [positiveb] at hpos
          refine walk_amp_mono rest hpos amp amp' hamp _ _ ?_ s h
          rw [walk_single_amp, walk_single_amp]
          exact Or.imp hpq (hamp s)
      | face t =>
          simp only [positiveb] at hpos
          refine walk_amp_mono rest hpos amp amp' hamp _ _ ?_ s h
          rw [walk_single_face, walk_single_face]
          exact Or.imp hpq id
      | range lo hi =>
          simp only [positiveb] at hpos
          refine walk_amp_mono rest hpos amp amp' hamp _ _ ?_ s h
          rw [walk_single_range, walk_single_range]
          exact Or.imp hpq id
      | final lo =>
          simp only [positiveb] at hpos
          refine walk_amp_mono rest hpos amp amp' hamp _ _ ?_ s h
          rw [walk_single_final, walk_single_final]
          exact Or.imp hpq id
      | fold inner =>
          simp only [positiveb] at hpos
          refine walk_amp_mono rest hpos amp amp' hamp _ _ ?_ s h
          rw [walk_single_fold, walk_single_fold]
          exact Or.imp hpq
            ((spells_amp_irrel (.fold inner) (by simp only [freeAmpb]) amp amp' s).mp)
      | prod fs =>
          simp only [positiveb] at hpos
          refine walk_amp_mono rest hpos amp amp' hamp _ _ ?_ s h
          rw [walk_single_prod, walk_single_prod]
          exact Or.imp hpq (fsplit_amp_mono fs amp amp' hamp s)

/- ---------------------------------------------------------------- -/
/- Layer 2: a positive walk is continuous over a chain of amps.      -/
/- ---------------------------------------------------------------- -/

/-- Continuity for a factor split: a split over the union of a chain happens over one element of
the chain, because a split consumes finitely many `&` reads and the chain is directed. -/
theorem fsplit_amp_cont : ∀ (fs : Factors) (c : ℕ → Spelling → Prop),
    (∀ k j, k ≤ j → ∀ t, c k t → c j t) →
    ∀ s, fsplit fs (fun t => ∃ k, c k t) s → ∃ K, fsplit fs (c K) s
  | .nil, _, _, s => by
      rw [fsplit_fnil]
      intro h
      exact ⟨0, by rw [fsplit_fnil]; exact h⟩
  | .amp rest, c, hc, s => by
      rw [fsplit_famp]
      rintro ⟨p, q, rfl, ⟨k1, hp⟩, hq⟩
      obtain ⟨K2, hq'⟩ := fsplit_amp_cont rest c hc q hq
      refine ⟨max k1 K2, ?_⟩
      rw [fsplit_famp]
      exact ⟨p, q, rfl, hc k1 _ (le_max_left _ _) p hp,
        fsplit_amp_mono rest (c K2) (c (max k1 K2)) (hc K2 _ (le_max_right _ _)) q hq'⟩
  | .node n rest, c, hc, s => by
      rw [fsplit_fnode]
      rintro ⟨p, q, rfl, hp, hq⟩
      obtain ⟨K, hq'⟩ := fsplit_amp_cont rest c hc q hq
      refine ⟨K, ?_⟩
      rw [fsplit_fnode]
      exact ⟨p, q, rfl, (ndenote_amp_indep n _ _ p).mp hp, hq'⟩

/-- Continuity for a positive walk, the accumulator generalized to a chain of propositions threaded
alongside the amp chain -- the doc's "every constructor is continuous in a positive slot". -/
theorem walk_amp_cont : ∀ (n : Node), positiveb n = true →
    ∀ (c : ℕ → Spelling → Prop), (∀ k j, k ≤ j → ∀ t, c k t → c j t) →
    ∀ (Q : ℕ → Prop), (∀ k j, k ≤ j → Q k → Q j) →
    ∀ s, walk n (fun t => ∃ k, c k t) (∃ k, Q k) s → ∃ K, walk n (c K) (Q K) s
  | .nil, _, c, hc, Q, hQ, s, h => by
      simp only [walk] at h
      obtain ⟨k, hk⟩ := h
      exact ⟨k, by simp only [walk]; exact hk⟩
  | .cons m rest, hpos, c, hc, Q, hQ, s, h => by
      rw [walk_cons] at h
      cases m with
      | sub op =>
          simp only [positiveb, Bool.and_eq_true, Bool.not_eq_true'] at hpos
          obtain ⟨hop, hrest⟩ := hpos
          have hmem : walk (nsingle (.sub op)) (fun t => ∃ k, c k t) (∃ k, Q k) s →
              ∃ k, walk (nsingle (.sub op)) (c k) (Q k) s := by
            rw [walk_single_sub]
            rintro ⟨⟨k, hQk⟩, hnw⟩
            refine ⟨k, ?_⟩
            rw [walk_single_sub]
            exact ⟨hQk, fun hw =>
              hnw ((walk_amp_irrel op hop (c k) (fun t => ∃ k, c k t) False s).mp hw)⟩
          have hmono : ∀ k j, k ≤ j → walk (nsingle (.sub op)) (c k) (Q k) s →
              walk (nsingle (.sub op)) (c j) (Q j) s := by
            intro k j hkj
            rw [walk_single_sub, walk_single_sub]
            rintro ⟨hQk, hnw⟩
            exact ⟨hQ k j hkj hQk, fun hw =>
              hnw ((walk_amp_irrel op hop (c j) (c k) False s).mp hw)⟩
          obtain ⟨K, hK⟩ :=
            walk_amp_cont rest hrest c hc _ hmono s (walk_mono rest _ s _ _ hmem h)
          exact ⟨K, by rw [walk_cons]; exact hK⟩
      | amp =>
          simp only [positiveb] at hpos
          have hmem : walk (nsingle .amp) (fun t => ∃ k, c k t) (∃ k, Q k) s →
              ∃ k, walk (nsingle .amp) (c k) (Q k) s := by
            rw [walk_single_amp]
            rintro (⟨k, hQk⟩ | ⟨k, hck⟩)
            · exact ⟨k, by rw [walk_single_amp]; exact Or.inl hQk⟩
            · exact ⟨k, by rw [walk_single_amp]; exact Or.inr hck⟩
          have hmono : ∀ k j, k ≤ j → walk (nsingle .amp) (c k) (Q k) s →
              walk (nsingle .amp) (c j) (Q j) s := by
            intro k j hkj
            rw [walk_single_amp, walk_single_amp]
            exact Or.imp (hQ k j hkj) (hc k j hkj s)
          obtain ⟨K, hK⟩ :=
            walk_amp_cont rest hpos c hc _ hmono s (walk_mono rest _ s _ _ hmem h)
          exact ⟨K, by rw [walk_cons]; exact hK⟩
      | face t =>
          simp only [positiveb] at hpos
          have hmem : walk (nsingle (.face t)) (fun u => ∃ k, c k u) (∃ k, Q k) s →
              ∃ k, walk (nsingle (.face t)) (c k) (Q k) s := by
            rw [walk_single_face]
            rintro (⟨k, hQk⟩ | hst)
            · exact ⟨k, by rw [walk_single_face]; exact Or.inl hQk⟩
            · exact ⟨0, by rw [walk_single_face]; exact Or.inr hst⟩
          have hmono : ∀ k j, k ≤ j → walk (nsingle (.face t)) (c k) (Q k) s →
              walk (nsingle (.face t)) (c j) (Q j) s := by
            intro k j hkj
            rw [walk_single_face, walk_single_face]
            exact Or.imp (hQ k j hkj) id
          obtain ⟨K, hK⟩ :=
            walk_amp_cont rest hpos c hc _ hmono s (walk_mono rest _ s _ _ hmem h)
          exact ⟨K, by rw [walk_cons]; exact hK⟩
      | range lo hi =>
          simp only [positiveb] at hpos
          have hmem : walk (nsingle (.range lo hi)) (fun u => ∃ k, c k u) (∃ k, Q k) s →
              ∃ k, walk (nsingle (.range lo hi)) (c k) (Q k) s := by
            rw [walk_single_range]
            rintro (⟨k, hQk⟩ | hwin)
            · exact ⟨k, by rw [walk_single_range]; exact Or.inl hQk⟩
            · exact ⟨0, by rw [walk_single_range]; exact Or.inr hwin⟩
          have hmono : ∀ k j, k ≤ j → walk (nsingle (.range lo hi)) (c k) (Q k) s →
              walk (nsingle (.range lo hi)) (c j) (Q j) s := by
            intro k j hkj
            rw [walk_single_range, walk_single_range]
            exact Or.imp (hQ k j hkj) id
          obtain ⟨K, hK⟩ :=
            walk_amp_cont rest hpos c hc _ hmono s (walk_mono rest _ s _ _ hmem h)
          exact ⟨K, by rw [walk_cons]; exact hK⟩
      | final lo =>
          simp only [positiveb] at hpos
          have hmem : walk (nsingle (.final lo)) (fun u => ∃ k, c k u) (∃ k, Q k) s →
              ∃ k, walk (nsingle (.final lo)) (c k) (Q k) s := by
            rw [walk_single_final]
            rintro (⟨k, hQk⟩ | hwin)
            · exact ⟨k, by rw [walk_single_final]; exact Or.inl hQk⟩
            · exact ⟨0, by rw [walk_single_final]; exact Or.inr hwin⟩
          have hmono : ∀ k j, k ≤ j → walk (nsingle (.final lo)) (c k) (Q k) s →
              walk (nsingle (.final lo)) (c j) (Q j) s := by
            intro k j hkj
            rw [walk_single_final, walk_single_final]
            exact Or.imp (hQ k j hkj) id
          obtain ⟨K, hK⟩ :=
            walk_amp_cont rest hpos c hc _ hmono s (walk_mono rest _ s _ _ hmem h)
          exact ⟨K, by rw [walk_cons]; exact hK⟩
      | fold inner =>
          simp only [positiveb] at hpos
          have hmem : walk (nsingle (.fold inner)) (fun u => ∃ k, c k u) (∃ k, Q k) s →
              ∃ k, walk (nsingle (.fold inner)) (c k) (Q k) s := by
            rw [walk_single_fold]
            rintro (⟨k, hQk⟩ | hsp)
            · exact ⟨k, by rw [walk_single_fold]; exact Or.inl hQk⟩
            · refine ⟨0, ?_⟩
              rw [walk_single_fold]
              exact Or.inr ((spells_amp_irrel (.fold inner) (by simp only [freeAmpb])
                (fun u => ∃ k, c k u) (c 0) s).mp hsp)
          have hmono : ∀ k j, k ≤ j → walk (nsingle (.fold inner)) (c k) (Q k) s →
              walk (nsingle (.fold inner)) (c j) (Q j) s := by
            intro k j hkj
            rw [walk_single_fold, walk_single_fold]
            exact Or.imp (hQ k j hkj)
              ((spells_amp_irrel (.fold inner) (by simp only [freeAmpb]) (c k) (c j) s).mp)
          obtain ⟨K, hK⟩ :=
            walk_amp_cont rest hpos c hc _ hmono s (walk_mono rest _ s _ _ hmem h)
          exact ⟨K, by rw [walk_cons]; exact hK⟩
      | prod fs =>
          simp only [positiveb] at hpos
          have hmem : walk (nsingle (.prod fs)) (fun u => ∃ k, c k u) (∃ k, Q k) s →
              ∃ k, walk (nsingle (.prod fs)) (c k) (Q k) s := by
            rw [walk_single_prod]
            rintro (⟨k, hQk⟩ | hfs)
            · exact ⟨k, by rw [walk_single_prod]; exact Or.inl hQk⟩
            · obtain ⟨K, hf⟩ := fsplit_amp_cont fs c hc s hfs
              exact ⟨K, by rw [walk_single_prod]; exact Or.inr hf⟩
          have hmono : ∀ k j, k ≤ j → walk (nsingle (.prod fs)) (c k) (Q k) s →
              walk (nsingle (.prod fs)) (c j) (Q j) s := by
            intro k j hkj
            rw [walk_single_prod, walk_single_prod]
            exact Or.imp (hQ k j hkj) (fsplit_amp_mono fs (c k) (c j) (hc k j hkj) s)
          obtain ⟨K, hK⟩ :=
            walk_amp_cont rest hpos c hc _ hmono s (walk_mono rest _ s _ _ hmem h)
          exact ⟨K, by rw [walk_cons]; exact hK⟩

/- ---------------------------------------------------------------- -/
/- Layer 3: the closure at omega is the least fixpoint.              -/
/- ---------------------------------------------------------------- -/

/-- Forward: one more application of a positive body adds nothing -- the closure is a prefixpoint.
This is where continuity earns its keep: a walk over the whole closure lands in a single stage. -/
theorem positive_prefixpoint (n : Node) (hpos : positiveb n = true) (s : Spelling)
    (h : walk n (closureD n) False s) : closureD n s := by
  have h' : walk n (fun t => ∃ k, stage n k t) (∃ _ : ℕ, False) s :=
    walk_mono n _ s False _ (fun f => f.elim) h
  obtain ⟨K, hK⟩ :=
    walk_amp_cont n hpos (stage n) (stage_chain n) (fun _ => False) (fun _ _ _ h => h) s h'
  exact ⟨K + 1, by rw [stage_succ]; exact Or.inr hK⟩

/-- Backward: everything in the closure is reproduced by one application of the body -- the closure
is a postfixpoint. -/
theorem positive_postfixpoint (n : Node) (hpos : positiveb n = true) (s : Spelling)
    (h : closureD n s) : walk n (closureD n) False s := by
  obtain ⟨k, hk⟩ := h
  exact stage_invariant n (walk n (closureD n) False)
    (fun k _ t hw => walk_amp_mono n hpos (stage n k) (closureD n)
      (fun u hu => ⟨k, hu⟩) False False id t hw) k s hk

/-- Headline (fixpoint on positive bodies), part 1: the closure at omega is a genuine fixpoint of
its body. -/
theorem positive_fixpoint (n : Node) (hpos : positiveb n = true) (s : Spelling) :
    walk n (closureD n) False s ↔ closureD n s :=
  ⟨positive_prefixpoint n hpos s, positive_postfixpoint n hpos s⟩

/-- Headline part 2: the closure is *least* -- any prefixpoint of the body contains it, stage by
stage. Together with `positive_fixpoint` this is the doc's "a positive body's closure is its least
fixpoint". -/
theorem positive_least (n : Node) (hpos : positiveb n = true) (F : Spelling → Prop)
    (hF : ∀ t, walk n F False t → F t) : ∀ s, closureD n s → F s := by
  rintro s ⟨k, hk⟩
  exact stage_invariant n F
    (fun k ih t hw => hF t (walk_amp_mono n hpos (stage n k) F ih False False id t hw))
    k s hk

/- ---------------------------------------------------------------- -/
/- The inflationary stages and the bare ones agree.                  -/
/- ---------------------------------------------------------------- -/

/-- The bare (non-inflationary) stages: `Y_{k+1} = body(Y_k)`, with no union of the previous
stage. -/
def bstage (n : Node) : ℕ → Spelling → Prop
  | 0, _ => False
  | k + 1, s => walk n (bstage n k) False s

/-- On a positive body the bare stages form a chain: monotonicity pushes each stage into the
next. -/
theorem bstage_mono_succ (n : Node) (hpos : positiveb n = true) :
    ∀ k s, bstage n k s → bstage n (k + 1) s
  | 0, _, h => h.elim
  | k + 1, s, h =>
      walk_amp_mono n hpos (bstage n k) (bstage n (k + 1))
        (bstage_mono_succ n hpos k) False False id s h

theorem bstage_chain (n : Node) (hpos : positiveb n = true) :
    ∀ k j, k ≤ j → ∀ t, bstage n k t → bstage n j t := by
  intro k j hkj
  induction hkj with
  | refl => exact fun t => id
  | step _ ih => exact fun t ht => bstage_mono_succ n hpos _ t (ih t ht)

/-- Headline part 3: "the inflationary stages and the bare ones agree" -- on a positive body the
two stage ladders have the same union, so either reading of "closure at omega" denotes the same
universe. -/
theorem bare_stages_agree (n : Node) (hpos : positiveb n = true) (s : Spelling) :
    (∃ k, stage n k s) ↔ (∃ k, bstage n k s) := by
  constructor
  · rintro ⟨k, hk⟩
    refine stage_invariant n (fun t => ∃ j, bstage n j t) (fun k ih t hw => ?_) k s hk
    have hw' : walk n (fun u => ∃ j, bstage n j u) (∃ _ : ℕ, False) t :=
      walk_amp_mono n hpos (stage n k) _ ih False _ (fun f => f.elim) t hw
    obtain ⟨K, hK⟩ := walk_amp_cont n hpos (bstage n) (bstage_chain n hpos)
      (fun _ => False) (fun _ _ _ h => h) t hw'
    exact ⟨K + 1, hK⟩
  · suffices hsuff : ∀ k s, bstage n k s → closureD n s by
      rintro ⟨k, hk⟩
      exact hsuff k s hk
    intro k
    induction k with
    | zero =>
        intro s hk
        exact hk.elim
    | succ k ih =>
        intro s hk
        exact positive_prefixpoint n hpos s
          (walk_amp_mono n hpos (bstage n k) (closureD n) ih False False id s hk)

end L1
