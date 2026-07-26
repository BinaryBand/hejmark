/- L1 guarded settling: the keystone bound behind the evaluator.

The doc (`docs/foundation/L1.md`, "Fixpoint on settled bodies") claims a
guarded body lengthens every spelling each pass, so a spelling of length `L`
settles -- present or absent -- by stage `L + 1`. That length-bounded stage is
exactly the `s.length + 1` bound `containsb` computes at, so this file is the
completeness partner of `Evaluator.lean`'s `containsb_sound`.

The development is three layers:

- amp-irrelevance: a non-binder node's walk ignores the ambient `amp`. Needed
  because a settled node reads `amp` only through a guarded product, and the
  guard factor (an `&`-free factor, hence a non-binder) together with the
  fold's `∀ t` clause must be shown independent of `amp`.
- locality: a settled node's walk of `s` depends on `amp` only at spellings
  strictly shorter than `s`, because the guard factor consumes at least one
  character, so every `&`-reference lands on a proper subspelling.
- stabilization: strong induction on `|s|` turns locality into "stages stop
  changing at short lengths by stage `|s| + 1`", whose corollary is that
  membership in the closure is settled at stage `|s| + 1`. -/
import L1.Membership.Evaluator

namespace L1

/- ---------------------------------------------------------------- -/
/- Layer 1: a non-binder ignores the ambient amp. Every ambient-amp  -/
/- read in the walk sits behind a free `&` (`bindsb`), so a node,     -/
/- member, or factor list with none reads the same under any amp.    -/
/- ---------------------------------------------------------------- -/

mutual
theorem walk_amp_irrel : ∀ (n : Node), bindsb n = false →
    ∀ (amp amp' : Spelling → Prop) (P : Prop) (s : Spelling),
    (walk n amp P s ↔ walk n amp' P s)
  | .nil, _, _, _, _, _ => by simp only [walk]
  | .cons m rest, hb, amp, amp', P, s => by
      simp only [bindsb, Bool.or_eq_false_iff] at hb
      obtain ⟨hbm, hbr⟩ := hb
      rw [walk_cons, walk_cons]
      have hmem : walk (nsingle m) amp P s ↔ walk (nsingle m) amp' P s := by
        cases m with
        | amp => simp [freeAmpb] at hbm
        | sub op =>
            simp only [freeAmpb] at hbm
            rw [walk_single_sub, walk_single_sub,
              walk_amp_irrel op hbm amp amp' False s]
        | face t => rw [walk_single_face, walk_single_face]
        | range lo hi => rw [walk_single_range, walk_single_range]
        | fold inner =>
            rw [walk_single_fold, walk_single_fold,
              spells_amp_irrel (.fold inner) hbm amp amp' s]
        | prod fs =>
            rw [walk_single_prod, walk_single_prod]
            simp only [freeAmpb] at hbm
            rw [fsplit_amp_irrel fs hbm amp amp' s]
      calc walk rest amp (walk (nsingle m) amp P s) s
          ↔ walk rest amp' (walk (nsingle m) amp P s) s :=
            walk_amp_irrel rest hbr amp amp' _ s
        _ ↔ walk rest amp' (walk (nsingle m) amp' P s) s :=
            walk_acc_iff rest amp' s _ _ hmem
theorem spells_amp_irrel : ∀ (m : Member), freeAmpb m = false →
    ∀ (amp amp' : Spelling → Prop) (s : Spelling),
    (spells m amp s ↔ spells m amp' s)
  | .face t, _, _, _, _ => by simp only [spells]
  | .range lo hi, _, _, _, _ => by simp only [spells]
  | .amp, hb, _, _, _ => by simp [freeAmpb] at hb
  | .sub op, _, _, _, _ => by simp only [spells]
  | .fold inner, _, amp, amp', s => by
      rw [spells_fold, spells_fold]
      cases hbi : bindsb inner with
      | true => simp only [if_true]
      | false =>
          simp only [Bool.false_eq_true, if_false]
          have hw := fun t => walk_amp_irrel inner hbi amp amp' False t
          simp only [hw]
  | .prod fs, hb, amp, amp', s => by
      simp only [freeAmpb] at hb
      rw [spells_prod, spells_prod, fsplit_amp_irrel fs hb amp amp' s]
theorem fsplit_amp_irrel : ∀ (fs : Factors), hasAmpb fs = false →
    ∀ (amp amp' : Spelling → Prop) (s : Spelling),
    (fsplit fs amp s ↔ fsplit fs amp' s)
  | .nil, _, _, _, _ => by rw [fsplit_fnil, fsplit_fnil]
  | .amp _, hb, _, _, _ => by simp [hasAmpb] at hb
  | .node n rest, hb, amp, amp', s => by
      simp only [hasAmpb] at hb
      rw [fsplit_fnode, fsplit_fnode]
      have hn : ∀ p, ndenote n amp p ↔ ndenote n amp' p := by
        intro p
        cases hbn : bindsb n with
        | true => rw [ndenote_binder n amp p hbn, ndenote_binder n amp' p hbn]
        | false =>
            rw [ndenote_nonbinder n amp p hbn, ndenote_nonbinder n amp' p hbn,
              walk_amp_irrel n hbn amp amp' False p]
      have hr := fun q => fsplit_amp_irrel rest hb amp amp' q
      simp only [hn, hr]
end

/- ---------------------------------------------------------------- -/
/- Layer 2: locality. Semantic guardedness first: an `&`-free factor  -/
/- wearing no empty face. This is the semantic form of the naive      -/
/- `&`-free-guard check (Python's `_settled`), but the empty-face     -/
/- test is the Prop denotation `¬ walk n _ False []` rather than the  -/
/- evaluator's `containsb n []`; connecting the two is the            -/
/- completeness bridge deferred to the next stage. -/
/- ---------------------------------------------------------------- -/

/-- An `&`-free factor (a non-binder) wearing no empty face. By
amp-irrelevance the empty-face test does not depend on the amp. -/
def semGuardFactor (n : Node) : Prop :=
  bindsb n = false ∧ ¬ walk n (fun _ => False) False []

/-- A factor list with at least one semantic guard -- the semantic form of the
naive `&`-free-guard check. -/
def SemGuarded : Factors → Prop
  | .nil => False
  | .amp rest => SemGuarded rest
  | .node n rest => semGuardFactor n ∨ SemGuarded rest

mutual
/-- Semantic settledness: bare `&` is unsettled, an amp-bearing product must be
guarded, a subtraction operand must itself be settled. The semantic form of
Python's `_settled` guardedness check. -/
def SemSettledMember : Member → Prop
  | .amp => False
  | .prod fs => hasAmpb fs = true → SemGuarded fs
  | .sub inner => SemSettled inner
  | .face _ => True
  | .range _ _ => True
  | .fold _ => True
def SemSettled : Node → Prop
  | .nil => True
  | .cons m rest => SemSettledMember m ∧ SemSettled rest
end

/-- A product factor reads no ambient amp: a binder factor uses its own stages,
a non-binder factor is amp-irrelevant (layer 1). -/
theorem ndenote_amp_indep (n : Node) (amp amp' : Spelling → Prop) (p : Spelling) :
    ndenote n amp p ↔ ndenote n amp' p := by
  cases hbn : bindsb n with
  | true => rw [ndenote_binder n amp p hbn, ndenote_binder n amp' p hbn]
  | false =>
      rw [ndenote_nonbinder n amp p hbn, ndenote_nonbinder n amp' p hbn,
        walk_amp_irrel n hbn amp amp' False p]

/-- The guard bites: a guarded factor list only splits nonempty spellings,
because its guard factor wears no empty face. -/
theorem guarded_nonempty : ∀ (fs : Factors) (amp : Spelling → Prop) (q : Spelling),
    SemGuarded fs → fsplit fs amp q → 0 < q.length
  | .nil, _, _, hg, _ => by simp only [SemGuarded] at hg
  | .amp rest, amp, q, hg, hf => by
      simp only [SemGuarded] at hg
      rw [fsplit_famp] at hf
      obtain ⟨p, q', rfl, _, hf'⟩ := hf
      have := guarded_nonempty rest amp q' hg hf'
      simp only [List.length_append]; omega
  | .node n rest, amp, q, hg, hf => by
      rw [fsplit_fnode] at hf
      obtain ⟨p, q', rfl, hp, hf'⟩ := hf
      simp only [SemGuarded] at hg
      rcases hg with hguard | hrest
      · obtain ⟨hbn, hne⟩ := hguard
        have hpp : p ≠ [] := by
          intro h; subst h
          rw [ndenote_nonbinder n amp [] hbn,
            walk_amp_irrel n hbn amp (fun _ => False) False []] at hp
          exact hne hp
        have := List.length_pos_of_ne_nil hpp
        simp only [List.length_append]; omega
      · have := guarded_nonempty rest amp q' hrest hf'
        simp only [List.length_append]; omega

/-- Locality for a factor list, with a length credit `c` for the characters
already consumed by earlier factors: the guard (or a positive credit) forces
every `.amp` factor's piece to have length `< N`, where `N` is the original
spelling's length. The node factors are amp-independent outright. -/
theorem fsplit_local_credit :
    ∀ (fs : Factors) (amp amp' : Spelling → Prop) (s : Spelling) (c N : Nat),
    (SemGuarded fs ∨ 0 < c) → c + s.length = N →
    (∀ t, t.length < N → (amp t ↔ amp' t)) →
    (fsplit fs amp s ↔ fsplit fs amp' s)
  | .nil, _, _, _, _, _, _, _, _ => by rw [fsplit_fnil, fsplit_fnil]
  | .amp rest, amp, amp', s, c, N, hor, hlen, hag => by
      rw [fsplit_famp, fsplit_famp]
      have hdis : ∀ p : Spelling, SemGuarded rest ∨ 0 < c + p.length := by
        intro p
        rcases hor with hg | hc
        · exact Or.inl (by simpa only [SemGuarded] using hg)
        · exact Or.inr (by omega)
      have hshort : ∀ (a : Spelling → Prop) p q, s = p ++ q →
          fsplit rest a q → p.length < N := by
        intro a p q hs hfq
        subst hs
        rcases hor with hg | hc
        · simp only [SemGuarded] at hg
          have := guarded_nonempty rest a q hg hfq
          simp only [List.length_append] at hlen; omega
        · simp only [List.length_append] at hlen; omega
      have hreclen : ∀ p q : Spelling, s = p ++ q → c + p.length + q.length = N := by
        rintro p q rfl; simp only [List.length_append] at hlen; omega
      constructor
      · rintro ⟨p, q, rfl, hap, hfq⟩
        have hpN := hshort amp p q rfl hfq
        have hrec := fsplit_local_credit rest amp amp' q (c + p.length) N
          (hdis p) (hreclen p q rfl) hag
        exact ⟨p, q, rfl, (hag p hpN).mp hap, hrec.mp hfq⟩
      · rintro ⟨p, q, rfl, hap, hfq⟩
        have hpN := hshort amp' p q rfl hfq
        have hrec := fsplit_local_credit rest amp amp' q (c + p.length) N
          (hdis p) (hreclen p q rfl) hag
        exact ⟨p, q, rfl, (hag p hpN).mpr hap, hrec.mpr hfq⟩
  | .node n rest, amp, amp', s, c, N, hor, hlen, hag => by
      rw [fsplit_fnode, fsplit_fnode]
      have hn := fun p => ndenote_amp_indep n amp amp' p
      have hreclen : ∀ p q : Spelling, s = p ++ q → c + p.length + q.length = N := by
        rintro p q rfl; simp only [List.length_append] at hlen; omega
      -- The recursion credit: guard-in-rest, or the head factor is the guard
      -- (forcing its matched piece nonempty), or a positive incoming credit.
      have hdis : ∀ (a : Spelling → Prop) p, ndenote n a p →
          SemGuarded rest ∨ 0 < c + p.length := by
        intro a p hp
        rcases hor with hg | hc
        · simp only [SemGuarded] at hg
          rcases hg with hguard | hrest
          · obtain ⟨hbn, hne⟩ := hguard
            have hpp : p ≠ [] := by
              intro h; subst h
              rw [ndenote_nonbinder n a [] hbn,
                walk_amp_irrel n hbn a (fun _ => False) False []] at hp
              exact hne hp
            exact Or.inr (by have := List.length_pos_of_ne_nil hpp; omega)
          · exact Or.inl hrest
        · exact Or.inr (by omega)
      constructor
      · rintro ⟨p, q, rfl, hp, hfq⟩
        have hrec := fsplit_local_credit rest amp amp' q (c + p.length) N
          (hdis amp p hp) (hreclen p q rfl) hag
        exact ⟨p, q, rfl, (hn p).mp hp, hrec.mp hfq⟩
      · rintro ⟨p, q, rfl, hp, hfq⟩
        have hrec := fsplit_local_credit rest amp amp' q (c + p.length) N
          (hdis amp' p hp) (hreclen p q rfl) hag
        exact ⟨p, q, rfl, (hn p).mpr hp, hrec.mpr hfq⟩

/-- Locality for a factor list: amp-free lists are amp-irrelevant, guarded lists
run through the credit lemma at credit 0. -/
theorem fsplit_local (fs : Factors) (hs : hasAmpb fs = true → SemGuarded fs)
    (amp amp' : Spelling → Prop) (s : Spelling)
    (hag : ∀ t, t.length < s.length → (amp t ↔ amp' t)) :
    fsplit fs amp s ↔ fsplit fs amp' s := by
  cases hA : hasAmpb fs with
  | false => exact fsplit_amp_irrel fs hA amp amp' s
  | true =>
      exact fsplit_local_credit fs amp amp' s 0 s.length
        (Or.inl (hs hA)) (by simp) hag

/-- Locality for a member: a settled member's face set depends on the amp only
below `|s|`. The bare `&` is excluded (unsettled); a fold is amp-irrelevant
outright; a product runs through `fsplit_local`. -/
theorem spells_local (m : Member) (hs : SemSettledMember m)
    (amp amp' : Spelling → Prop) (s : Spelling)
    (hag : ∀ t, t.length < s.length → (amp t ↔ amp' t)) :
    spells m amp s ↔ spells m amp' s := by
  cases m with
  | face t => simp only [spells]
  | range lo hi => simp only [spells]
  | amp => simp only [SemSettledMember] at hs
  | sub op => simp only [spells]
  | fold inner =>
      exact spells_amp_irrel (.fold inner) (by simp only [freeAmpb]) amp amp' s
  | prod fs =>
      simp only [SemSettledMember] at hs
      rw [spells_prod, spells_prod]
      exact fsplit_local fs hs amp amp' s hag

/-- Locality for a node: a settled node's walk of `s` depends on the amp only at
spellings strictly shorter than `s`. This is the doc's "a guarded body only
reads shorter spellings", the mechanism behind the length-bounded stage. -/
theorem walk_local : ∀ (n : Node), SemSettled n →
    ∀ (amp amp' : Spelling → Prop) (P : Prop) (s : Spelling),
    (∀ t, t.length < s.length → (amp t ↔ amp' t)) →
    (walk n amp P s ↔ walk n amp' P s)
  | .nil, _, _, _, _, _, _ => by simp only [walk]
  | .cons m rest, hs, amp, amp', P, s, hag => by
      simp only [SemSettled] at hs
      obtain ⟨hsm, hsr⟩ := hs
      rw [walk_cons, walk_cons]
      have hmem : walk (nsingle m) amp P s ↔ walk (nsingle m) amp' P s := by
        cases m with
        | amp => simp only [SemSettledMember] at hsm
        | sub op =>
            rw [walk_single_sub, walk_single_sub]
            simp only [SemSettledMember] at hsm
            rw [walk_local op hsm amp amp' False s hag]
        | face t => rw [walk_single_face, walk_single_face]
        | range lo hi => rw [walk_single_range, walk_single_range]
        | fold inner =>
            rw [walk_single_fold, walk_single_fold,
              spells_local (.fold inner) hsm amp amp' s hag]
        | prod fs =>
            rw [walk_single_prod, walk_single_prod]
            simp only [SemSettledMember] at hsm
            rw [fsplit_local fs hsm amp amp' s hag]
      calc walk rest amp (walk (nsingle m) amp P s) s
          ↔ walk rest amp' (walk (nsingle m) amp P s) s :=
            walk_local rest hsr amp amp' _ s hag
        _ ↔ walk rest amp' (walk (nsingle m) amp' P s) s :=
            walk_acc_iff rest amp' s _ _ hmem

/- ---------------------------------------------------------------- -/
/- Layer 3: stabilization and the settling bound. Strong induction   -/
/- on `|s|`: a settled body's walk of `s` reads its amp only at       -/
/- strictly shorter spellings (locality), which have already settled  -/
/- by their own length; so at any two stages `>= |s|+1` those reads   -/
/- agree, and the stage of `s` no longer moves.                       -/
/- ---------------------------------------------------------------- -/

/-- Stabilization, indexed by the spelling length `L` for the strong induction:
past stage `L + 1`, membership of a length-`L` spelling never changes. -/
theorem stage_stab_aux (n : Node) (hs : SemSettled n) :
    ∀ (L : Nat) (s : Spelling), s.length = L →
    ∀ j, L + 1 ≤ j → stage n j s → stage n (L + 1) s := by
  intro L
  induction L using Nat.strong_induction_on
  rename_i L IH
  intro s hLs j hj
  induction j, hj using Nat.le_induction with
  | base => intro h; exact h
  | succ j hj IHj =>
      intro hstage
      rw [stage_succ] at hstage
      rcases hstage with hprev | hbody
      · exact IHj hprev
      · have hagree : ∀ t, t.length < s.length → (stage n j t ↔ stage n L t) := by
          intro t ht
          rw [hLs] at ht
          refine ⟨fun htj => ?_, fun htL => ?_⟩
          · exact stage_mono_le n (t.length + 1) L t (by omega)
              (IH t.length ht t rfl j (by omega) htj)
          · exact stage_mono_le n L j t (by omega) htL
        have hwalk := (walk_local n hs (stage n j) (stage n L) False s hagree).mp hbody
        rw [stage_succ]; exact Or.inr hwalk

/-- The keystone: on a settled body, membership in the closure at omega is
decided at stage `|s| + 1`. This is the completeness partner of
`containsb_sound` and the doc's length-bounded settling bound. -/
theorem guarded_settles (n : Node) (hs : SemSettled n) (s : Spelling)
    (h : ∃ k, stage n k s) : stage n (s.length + 1) s := by
  obtain ⟨k, hk⟩ := h
  rcases Nat.le_total k (s.length + 1) with hle | hge
  · exact stage_mono_le n k (s.length + 1) s hle hk
  · exact stage_stab_aux n hs s.length s rfl k hge hk

/-- Repackaged over `ndenote`: a settled binder's closure membership is exactly
its stage-`|s|+1` value, so the doc's "decided at a length-bounded stage" holds
verbatim. -/
theorem settled_binder_bound (n : Node) (hs : SemSettled n) (s : Spelling)
    (hb : bindsb n = true) :
    ndenote n (fun _ => False) s ↔ stage n (s.length + 1) s := by
  rw [ndenote_binder n _ s hb]
  exact ⟨guarded_settles n hs s, fun h => ⟨s.length + 1, h⟩⟩

/- ---------------------------------------------------------------- -/
/- The boolean bridge: `settledExactb` implies `SemSettled`.          -/
/-                                                                    -/
/- The naive settledness check (Python's `_settled`: every free `&`   -/
/- guarded by an `&`-free factor with no empty face, tested by         -/
/- `!(containsb n [])`) does NOT imply `SemSettled`: that test rides    -/
/- the sound fold-unit surrogate (`addsb = false`), so `containsb`      -/
/- misses a fold's empty face where the Prop spec wears it -- e.g. the  -/
/- guard `{{a,!{a}}}` reads as nonempty to `containsb` yet is           -/
/- denotationally the unit, so the naive check accepts an unguarded     -/
/- body.                                                                -/
/-                                                                      -/
/- The honest bridge strengthens the guard witness to the exact        -/
/- fragment (`exactNodeb`), where the evaluator is two-sided            -/
/- (`exact_node`), so `containsb n [] = false` genuinely certifies no   -/
/- empty face. This is the checker `guarded_settles` actually applies   -/
/- to; connecting it to the naive `!(bindsb n)` guard would need the    -/
/- fold-unit surrogate closed, which the doc keeps open.                -/
/- ---------------------------------------------------------------- -/

/-- A guarded factor list, with each guard witness pinned to the exact fragment
so its empty-face test is decidable. Strengthens the naive `&`-free-guard check
by replacing its `!(bindsb n)` witness condition with the stronger `exactNodeb n`. -/
def guardedExactFactorb : Factors → Bool
  | .nil => false
  | .amp rest => guardedExactFactorb rest
  | .node n rest =>
      (exactNodeb n && !(bindsb n) && !(containsb n [])) || guardedExactFactorb rest

mutual
/-- Settledness with exact guards: the naive settledness check with its guard
test strengthened to `guardedExactFactorb`. -/
def settledExactMemberb : Member → Bool
  | .amp => false
  | .prod fs => if hasAmpb fs then guardedExactFactorb fs else true
  | .sub inner => settledExactb inner
  | _ => true
def settledExactb : Node → Bool
  | .nil => true
  | .cons m rest => settledExactMemberb m && settledExactb rest
end

/-- The factor-level bridge: an exact-guarded factor list is semantically
guarded. The exact guard witness `n` reads `containsb n [] = false`, which
`exact_node` turns into `¬ walk n _ False []` -- a genuine empty-face absence. -/
theorem semGuarded_of_guardedExactFactorb :
    ∀ (fs : Factors), guardedExactFactorb fs = true → SemGuarded fs
  | .nil, h => by simp [guardedExactFactorb] at h
  | .amp rest, h => by
      simp only [guardedExactFactorb] at h
      exact semGuarded_of_guardedExactFactorb rest h
  | .node n rest, h => by
      simp only [guardedExactFactorb, Bool.or_eq_true, Bool.and_eq_true] at h
      rcases h with ⟨⟨hx, hnb⟩, hc⟩ | hrest
      · refine Or.inl ?_
        have hb : bindsb n = false := by simpa using hnb
        refine ⟨hb, ?_⟩
        have hcw : walkb n (fun _ => false) false [] = false := by
          simpa [containsb, hb] using hc
        have hiff := exact_node n hx (fun _ => false) (fun _ => False) false False []
          (by simp)
        intro hw
        rw [hiff.mpr hw] at hcw
        simp at hcw
      · exact Or.inr (semGuarded_of_guardedExactFactorb rest hrest)

mutual
/-- The member-level bridge. -/
theorem semSettledMember_of_settledExactMemberb :
    ∀ (m : Member), settledExactMemberb m = true → SemSettledMember m
  | .amp, h => by simp [settledExactMemberb] at h
  | .prod fs, h => by
      simp only [SemSettledMember]
      intro hA
      simp only [settledExactMemberb, hA, if_true] at h
      exact semGuarded_of_guardedExactFactorb fs h
  | .sub inner, h => by
      simp only [settledExactMemberb] at h
      exact semSettled_of_settledExactb inner h
  | .face _, _ => by simp only [SemSettledMember]
  | .range _ _, _ => by simp only [SemSettledMember]
  | .fold _, _ => by simp only [SemSettledMember]
/-- The node-level bridge, headline: the exact-guarded checker certifies
semantic settledness, so `guarded_settles` applies to a boolean-checkable
fragment of bodies. -/
theorem semSettled_of_settledExactb :
    ∀ (n : Node), settledExactb n = true → SemSettled n
  | .nil, _ => by simp only [SemSettled]
  | .cons m rest, h => by
      simp only [settledExactb, Bool.and_eq_true] at h
      exact ⟨semSettledMember_of_settledExactMemberb m h.1,
        semSettled_of_settledExactb rest h.2⟩
end

end L1
