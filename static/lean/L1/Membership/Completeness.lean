/- L1 evaluator completeness: the reverse of `containsb_sound`, giving the
crown two-sided `iff` on the settled fragment.

`Evaluator.lean` proves soundness: on the `sndb` fragment, whatever `containsb`
asserts the universe denotationally wears. This file proves the converse on a
matching fragment (`cmpb`): whatever the universe wears, `containsb` asserts.
Together they give `containsb_exact`: `containsb n s = true <-> denotes n s`.

Completeness is the harder direction because `containsb` under-approximates in
two documented ways, and the fragment is exactly what rules those out:

- Closures answer at the length-bounded stage `|s| + 1`. Completeness there is
  the settling theorem (`guarded_settles`, `Settling.lean`), applied through the
  boolean bridge (`semSettled_of_settledExactb`): every binder in the fragment
  must pass `settledExactb`.
- A non-binder fold's empty face uses the sound surrogate `addsb = false`. A
  denotationally empty body with `addsb = true` (e.g. `{a,!{a}}`) is missed, so
  the fragment restricts non-binder fold bodies to `!(addsb inner)` (unit-like)
  or `manifestb inner` (manifestly nonempty, so the empty-face branch is dead).

Subtraction operands stay in the exact fragment (`exactNodeb`), shared with
soundness: under a subtraction each direction needs the other on the operand. -/
import L1.Membership.Settling

namespace L1

/- ---------------------------------------------------------------- -/
/- A subtraction-free member list only ever adds, so any accumulator -/
/- it starts with survives the walk.                                 -/
/- ---------------------------------------------------------------- -/

theorem subfree_acc (n : Node) (amp : Spelling → Prop) (P : Prop) (s : Spelling)
    (hsf : subfreeb n = true) (hp : P) : walk n amp P s :=
  (walk_adds n amp P s hsf).mpr (Or.inl hp)

/- ---------------------------------------------------------------- -/
/- Manifest nonemptiness: a face head with no subtraction after it    -/
/- certifies the body wears at least one spelling, so the fold-to-unit -/
/- empty-face branch cannot fire. A face is always nonempty, which     -/
/- ranges are not (a reversed range is empty), so only it anchors.     -/
/- ---------------------------------------------------------------- -/

def manifestHeadb : Member → Bool
  | .face _ => true
  | _ => false

def manifestb : Node → Bool
  | .nil => false
  | .cons m rest => (manifestHeadb m && subfreeb rest) || manifestb rest

theorem manifest_nonempty : ∀ (n : Node) (amp : Spelling → Prop),
    manifestb n = true → ∃ t, walk n amp False t
  | .nil, _, h => by simp [manifestb] at h
  | .cons m rest, amp, h => by
      simp only [manifestb, Bool.or_eq_true, Bool.and_eq_true] at h
      rcases h with ⟨hhead, hsf⟩ | hrest
      · cases m with
        | face t₀ =>
            refine ⟨t₀, ?_⟩
            rw [walk_cons]
            exact subfree_acc rest amp _ t₀ hsf
              (by rw [walk_single_face]; exact Or.inr rfl)
        | range lo hi => simp [manifestHeadb] at hhead
        | amp => simp [manifestHeadb] at hhead
        | sub op => simp [manifestHeadb] at hhead
        | fold inner => simp [manifestHeadb] at hhead
        | prod fs => simp [manifestHeadb] at hhead
      · obtain ⟨t, ht⟩ := manifest_nonempty rest amp hrest
        refine ⟨t, ?_⟩
        rw [walk_cons]
        exact walk_mono rest amp t False _ (fun hf => hf.elim) ht

/- ---------------------------------------------------------------- -/
/- Stage completeness: the dual of `stage_sound_of`. From body       -/
/- completeness, membership at stage k crosses to the boolean stage. -/
/- ---------------------------------------------------------------- -/

theorem stage_complete_of (n : Node)
    (hw : ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (Pb : Bool) (P : Prop)
      (s : Spelling), (∀ t, amp t → ampb t = true) → (P → Pb = true) →
      walk n amp P s → walkb n ampb Pb s = true) :
    ∀ (k : Nat) (s : Spelling), stage n k s → stageb n k s = true
  | 0, s, h => by rw [stage_zero] at h; exact h.elim
  | (k + 1), s, h => by
      rw [stageb_succ, Bool.or_eq_true]
      rw [stage_succ] at h
      rcases h with h | h
      · exact Or.inl (stage_complete_of n hw k s h)
      · exact Or.inr (hw (stageb n k) (stage n k) false False s
          (fun t ht => stage_complete_of n hw k t ht) (by simp) h)

/- ---------------------------------------------------------------- -/
/- The completeness fragment: closures must be exact-settled, non-   -/
/- binder folds unit-like or manifest, subtractions exact. Products  -/
/- carry the same closure obligation on binder factors.              -/
/- ---------------------------------------------------------------- -/

mutual
def cmpMemberb : Member → Bool
  | .face _ => true
  | .range _ _ => true
  | .amp => true
  | .sub op => exactNodeb op
  | .fold inner =>
      if bindsb inner then settledExactb inner && cmpNodeb inner
      else cmpNodeb inner && (!(addsb inner) || manifestb inner)
  | .prod fs => cmpFactorsb fs
def cmpNodeb : Node → Bool
  | .nil => true
  | .cons m rest => cmpMemberb m && cmpNodeb rest
def cmpFactorsb : Factors → Bool
  | .nil => true
  | .amp rest => cmpFactorsb rest
  | .node n rest =>
      (if bindsb n then settledExactb n && cmpNodeb n else cmpNodeb n) && cmpFactorsb rest
end

/- ---------------------------------------------------------------- -/
/- Two-sided completeness on the fragment: whatever the walk denotes, -/
/- the boolean evaluator computes. The mirror of snd_member/node/     -/
/- factors, with the amp relation and accumulator relation flipped.   -/
/- ---------------------------------------------------------------- -/

mutual
theorem cmp_member : ∀ (m : Member), cmpMemberb m = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (Pb : Bool) (P : Prop) (s : Spelling),
    (∀ t, amp t → ampb t = true) → (P → Pb = true) →
    walk (nsingle m) amp P s → walkb (nsingle m) ampb Pb s = true
  | .face t, _, ampb, amp, Pb, P, s, _, hacc, h => by
      rw [walk_single_face] at h
      rw [walkb_single_face, Bool.or_eq_true]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · exact Or.inr (beq_iff_eq.mpr h)
  | .range lo hi, _, ampb, amp, Pb, P, s, _, hacc, h => by
      rw [walk_single_range] at h
      rw [walkb_single_range, Bool.or_eq_true]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · exact Or.inr h
  | .amp, _, ampb, amp, Pb, P, s, hamp, hacc, h => by
      rw [walk_single_amp] at h
      rw [walkb_single_amp, Bool.or_eq_true]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · exact Or.inr (hamp s h)
  | .sub op, hx, ampb, amp, Pb, P, s, _, hacc, h => by
      simp only [cmpMemberb] at hx
      rw [walk_single_sub] at h
      rw [walkb_single_sub, Bool.and_eq_true]
      refine ⟨hacc h.1, ?_⟩
      cases hb : walkb op ampb false s with
      | false => rfl
      | true =>
          exact absurd ((exact_node op hx ampb amp false False s (by simp)).mp hb) h.2
  | .fold inner, hx, ampb, amp, Pb, P, s, hamp, hacc, h => by
      rw [walk_single_fold] at h
      rw [walkb_single_fold, Bool.or_eq_true]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · refine Or.inr ?_
        by_cases hbi : bindsb inner = true
        · rw [cmpMemberb, if_pos hbi, Bool.and_eq_true] at hx
          obtain ⟨hset, hcmpi⟩ := hx
          rw [spells_fold_binder inner amp s hbi] at h
          rw [spellsb_fold_binder inner ampb s hbi]
          obtain ⟨k, hk⟩ := h
          have hsem := semSettled_of_settledExactb inner hset
          have hst := guarded_settles inner hsem s ⟨k, hk⟩
          exact stage_complete_of inner (cmp_node inner hcmpi) (s.length + 1) s hst
        · have hb : bindsb inner = false := Bool.eq_false_iff.mpr hbi
          rw [cmpMemberb, if_neg hbi, Bool.and_eq_true, Bool.or_eq_true] at hx
          obtain ⟨hcmpi, hcond⟩ := hx
          rw [fold_membership inner amp s hb] at h
          rw [spellsb_fold_nonbinder inner ampb s hb, Bool.or_eq_true]
          rcases h with h | ⟨hnil, hempty⟩
          · exact Or.inl (cmp_node inner hcmpi ampb amp false False s hamp (by simp) h)
          · refine Or.inr ?_
            subst hnil
            rw [Bool.and_eq_true]
            refine ⟨rfl, ?_⟩
            rcases hcond with hadd | hmani
            · exact hadd
            · exfalso
              obtain ⟨t, ht⟩ := manifest_nonempty inner amp hmani
              exact hempty t ht
  | .prod fs, hx, ampb, amp, Pb, P, s, hamp, hacc, h => by
      simp only [cmpMemberb] at hx
      rw [walk_single_prod] at h
      rw [walkb_single_prod, Bool.or_eq_true]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · exact Or.inr (cmp_factors fs hx ampb amp s hamp h)
theorem cmp_node : ∀ (n : Node), cmpNodeb n = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (Pb : Bool) (P : Prop) (s : Spelling),
    (∀ t, amp t → ampb t = true) → (P → Pb = true) →
    walk n amp P s → walkb n ampb Pb s = true
  | .nil, _, ampb, amp, Pb, P, s, _, hacc, h => by
      rw [walk_nil] at h; simp only [walkb]; exact hacc h
  | .cons m rest, hx, ampb, amp, Pb, P, s, hamp, hacc, h => by
      simp only [cmpNodeb, Bool.and_eq_true] at hx
      rw [walk_cons] at h
      rw [walkb_cons]
      exact cmp_node rest hx.2 ampb amp _ _ s hamp
        (fun hm => cmp_member m hx.1 ampb amp Pb P s hamp hacc hm) h
theorem cmp_factors : ∀ (fs : Factors), cmpFactorsb fs = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (s : Spelling),
    (∀ t, amp t → ampb t = true) → fsplit fs amp s → fsplitb fs ampb s = true
  | .nil, _, ampb, amp, s, _, h => by
      rw [fsplit_fnil] at h; rw [fsplitb_fnil, isNilb_true_iff]; exact h
  | .amp rest, hx, ampb, amp, s, hamp, h => by
      simp only [cmpFactorsb] at hx
      rw [fsplit_famp] at h
      rw [fsplitb_famp, cuts_true_iff]
      obtain ⟨p, q, rfl, hap, hfq⟩ := h
      exact ⟨p, q, rfl, hamp p hap, cmp_factors rest hx ampb amp q hamp hfq⟩
  | .node n rest, hx, ampb, amp, s, hamp, h => by
      simp only [cmpFactorsb, Bool.and_eq_true] at hx
      obtain ⟨hn, hf⟩ := hx
      rw [fsplit_fnode] at h
      rw [fsplitb_fnode, cuts_true_iff]
      obtain ⟨p, q, rfl, h1, h2⟩ := h
      refine ⟨p, q, rfl, ?_, cmp_factors rest hf ampb amp q hamp h2⟩
      by_cases hb : bindsb n = true
      · rw [if_pos hb, Bool.and_eq_true] at hn
        obtain ⟨hset, hcmpi⟩ := hn
        rw [ndenote_binder n amp p hb] at h1
        rw [fcontainsb_binder n ampb p hb]
        obtain ⟨k, hk⟩ := h1
        have hsem := semSettled_of_settledExactb n hset
        have hst := guarded_settles n hsem p ⟨k, hk⟩
        exact stage_complete_of n (cmp_node n hcmpi) (p.length + 1) p hst
      · have hb' : bindsb n = false := Bool.eq_false_iff.mpr hb
        rw [if_neg hb] at hn
        rw [ndenote_nonbinder n amp p hb'] at h1
        rw [fcontainsb_nonbinder n ampb p hb']
        exact cmp_node n hn ampb amp false False p hamp (by simp) h1
end

/- ---------------------------------------------------------------- -/
/- The crown: on a fragment that is both sound and complete, and     -/
/- whose top-level binder is exact-settled, the evaluator is exactly  -/
/- the denotation.                                                    -/
/- ---------------------------------------------------------------- -/

theorem containsb_exact (n : Node) (s : Spelling)
    (hsnd : sndNodeb n = true) (hcmp : cmpNodeb n = true)
    (hset : bindsb n = true → settledExactb n = true) :
    containsb n s = true ↔ denotes n s := by
  refine ⟨fun h => containsb_sound n s hsnd h, fun h => ?_⟩
  rw [denotes] at h
  by_cases hb : bindsb n = true
  · simp only [containsb]; rw [if_pos hb]
    rw [ndenote_binder n _ s hb] at h
    have hsem := semSettled_of_settledExactb n (hset hb)
    exact stage_complete_of n (cmp_node n hcmp) (s.length + 1) s (guarded_settles n hsem s h)
  · have hb' : bindsb n = false := Bool.eq_false_iff.mpr hb
    simp only [containsb]; rw [if_neg hb]
    rw [ndenote_nonbinder n _ s hb'] at h
    exact cmp_node n hcmp (fun _ => false) (fun _ => False) false False s
      (by simp) (by simp) h

end L1
