/- L1 boolean evaluator: the same algorithm as `universe.py`'s `_contains`,
plus its soundness against the Prop denotation.

Port of `static/formal/L1/Evaluator.v`. `containsb` mirrors
`Universe.contains`: closure membership is decided at stage `length s + 1`,
exactly the Python bound. Two deliberate approximations against the Prop spec:

- Unsettled closures answer `false` at the stage bound (exactness on settled
  bodies is the deferred fixpoint theorem).
- The fold-to-unit boundary uses the sound surrogate "no adding member"
  (`addsb = false`). This is why soundness (`containsb_sound`) carries the
  `sndb` side condition: a subtraction operand must sit in the exact fragment
  (`exactb`), since under a subtraction the under-approximations would flip
  into unsoundness.

The north-star positive rows all live inside `sndb`, so they compute by
`native_decide` through `containsb_sound`. Completeness is deliberately not
attempted. -/
import L1.Membership.Laws

namespace L1

def isNilb : Spelling → Bool
  | [] => true
  | _ => false

theorem isNilb_true_iff (s : Spelling) : isNilb s = true ↔ s = [] := by
  cases s <;> simp [isNilb]

/- ---------------------------------------------------------------- -/
/- The evaluator: walkb/spellsb/fsplitb mirror walk/spells/fsplit    -/
/- with bool connectives, a bounded stage search for closures, and a -/
/- bounded cut search for products.                                  -/
/- ---------------------------------------------------------------- -/

mutual
def walkb : Node → (Spelling → Bool) → Bool → Spelling → Bool
  | .nil, _, Pb, _ => Pb
  | .cons (.sub op) rest, ampb, Pb, s =>
      walkb rest ampb (Pb && !(walkb op ampb false s)) s
  | .cons m rest, ampb, Pb, s => walkb rest ampb (Pb || spellsb m ampb s) s
  termination_by n _ _ _ => (sizeOf n, 0, 0)
def spellsb : Member → (Spelling → Bool) → Spelling → Bool
  | .face t, _, s => s == t
  | .range lo hi, _, s => winb (rangeWindow lo hi) s
  | .amp, ampb, s => ampb s
  | .sub _, _, _ => false
  | .fold inner, ampb, s =>
      if bindsb inner then stageb inner (s.length + 1) s
      else walkb inner ampb false s || (isNilb s && !(addsb inner))
  | .prod fs, ampb, s => fsplitb fs ampb s
  termination_by m _ _ => (sizeOf m, 0, 0)
def fsplitb : Factors → (Spelling → Bool) → Spelling → Bool
  | .nil, _, s => isNilb s
  | .amp rest, ampb, s =>
      (List.range (s.length + 1)).any
        (fun k => ampb (s.take k) && fsplitb rest ampb (s.drop k))
  | .node n rest, ampb, s =>
      (List.range (s.length + 1)).any
        (fun k =>
          (if bindsb n then stageb n ((s.take k).length + 1) (s.take k)
           else walkb n ampb false (s.take k))
          && fsplitb rest ampb (s.drop k))
  termination_by fs _ _ => (sizeOf fs, 0, 0)
def stageb : Node → Nat → Spelling → Bool
  | _, 0, _ => false
  | n, (k + 1), s => stageb n k s || walkb n (stageb n k) false s
  termination_by n k _ => (sizeOf n, k, 1)
end

/-- A product factor's membership, mirroring `_factor_contains`. -/
def fcontainsb (n : Node) (ampb : Spelling → Bool) (p : Spelling) : Bool :=
  if bindsb n then stageb n (p.length + 1) p else walkb n ampb false p

/-- Top-level membership, mirroring `Universe.contains` with amp = none: a
binder is decided at stage `length s + 1`. -/
def containsb (n : Node) (s : Spelling) : Bool :=
  if bindsb n then stageb n (s.length + 1) s else walkb n (fun _ => false) false s

/- ---------------------------------------------------------------- -/
/- Unfolding equations.                                              -/
/- ---------------------------------------------------------------- -/

theorem walkb_cons (m rest ampb Pb s) :
    walkb (.cons m rest) ampb Pb s
      = walkb rest ampb (walkb (nsingle m) ampb Pb s) s := by
  cases m <;> simp [walkb, nsingle]

theorem walkb_single_face (t ampb Pb s) :
    walkb (nsingle (.face t)) ampb Pb s = (Pb || (s == t)) := by
  simp only [nsingle, walkb, spellsb]

theorem walkb_single_range (lo hi ampb Pb s) :
    walkb (nsingle (.range lo hi)) ampb Pb s
      = (Pb || winb (rangeWindow lo hi) s) := by
  simp only [nsingle, walkb, spellsb]

theorem walkb_single_amp (ampb Pb s) :
    walkb (nsingle .amp) ampb Pb s = (Pb || ampb s) := by
  simp only [nsingle, walkb, spellsb]

theorem walkb_single_fold (inner ampb Pb s) :
    walkb (nsingle (.fold inner)) ampb Pb s
      = (Pb || spellsb (.fold inner) ampb s) := by
  simp only [nsingle, walkb]

theorem walkb_single_sub (op ampb Pb s) :
    walkb (nsingle (.sub op)) ampb Pb s = (Pb && !(walkb op ampb false s)) := by
  simp only [nsingle, walkb]

theorem walkb_single_prod (fs ampb Pb s) :
    walkb (nsingle (.prod fs)) ampb Pb s = (Pb || fsplitb fs ampb s) := by
  simp only [nsingle, walkb, spellsb]

theorem spellsb_fold (inner ampb s) :
    spellsb (.fold inner) ampb s
      = (if bindsb inner then stageb inner (s.length + 1) s
         else walkb inner ampb false s || (isNilb s && !(addsb inner))) := by
  simp only [spellsb]

theorem fsplitb_fnil (ampb s) : fsplitb .nil ampb s = isNilb s := by
  simp only [fsplitb]

theorem fsplitb_famp (rest ampb s) :
    fsplitb (.amp rest) ampb s
      = (List.range (s.length + 1)).any
          (fun k => ampb (s.take k) && fsplitb rest ampb (s.drop k)) := by
  simp only [fsplitb]

theorem fsplitb_fnode (n rest ampb s) :
    fsplitb (.node n rest) ampb s
      = (List.range (s.length + 1)).any
          (fun k => fcontainsb n ampb (s.take k) && fsplitb rest ampb (s.drop k)) := by
  simp only [fsplitb, fcontainsb]

theorem stageb_zero (n s) : stageb n 0 s = false := by simp only [stageb]

theorem stageb_succ (n k s) :
    stageb n (k + 1) s = (stageb n k s || walkb n (stageb n k) false s) := by
  simp only [stageb]

/- ---------------------------------------------------------------- -/
/- Cut search: the bounded split enumeration is exactly the claim    -/
/- that some decomposition s = p ++ q exists.                        -/
/- ---------------------------------------------------------------- -/

theorem cuts_true_iff (pb qb : Spelling → Bool) (s : Spelling) :
    ((List.range (s.length + 1)).any (fun k => pb (s.take k) && qb (s.drop k)) = true)
      ↔ ∃ p q, s = p ++ q ∧ pb p = true ∧ qb q = true := by
  rw [List.any_eq_true]
  constructor
  · rintro ⟨k, _, hk⟩
    rw [Bool.and_eq_true] at hk
    exact ⟨s.take k, s.drop k, (s.take_append_drop k).symm, hk.1, hk.2⟩
  · rintro ⟨p, q, rfl, h1, h2⟩
    refine ⟨p.length, ?_, ?_⟩
    · rw [List.mem_range, List.length_append]; omega
    · simp [h1, h2]

theorem fcontainsb_binder (n : Node) (ampb : Spelling → Bool) (p : Spelling)
    (hb : bindsb n = true) : fcontainsb n ampb p = stageb n (p.length + 1) p := by
  simp [fcontainsb, hb]

theorem fcontainsb_nonbinder (n : Node) (ampb : Spelling → Bool) (p : Spelling)
    (hb : bindsb n = false) : fcontainsb n ampb p = walkb n ampb false p := by
  simp [fcontainsb, hb]

theorem spells_fold_binder (inner : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb inner = true) : spells (.fold inner) amp s ↔ ∃ k, stage inner k s := by
  rw [spells_fold, hb]; simp

theorem spellsb_fold_binder (inner : Node) (ampb : Spelling → Bool) (s : Spelling)
    (hb : bindsb inner = true) :
    spellsb (.fold inner) ampb s = stageb inner (s.length + 1) s := by
  rw [spellsb_fold, hb]; simp

theorem spellsb_fold_nonbinder (inner : Node) (ampb : Spelling → Bool) (s : Spelling)
    (hb : bindsb inner = false) :
    spellsb (.fold inner) ampb s
      = (walkb inner ampb false s || (isNilb s && !(addsb inner))) := by
  rw [spellsb_fold, hb]; simp

/- ---------------------------------------------------------------- -/
/- The exact fragment: no `&`, no fold, no binder factor. On it the  -/
/- evaluator is two-sided, which is what a subtraction operand needs. -/
/- ---------------------------------------------------------------- -/

mutual
def exactMemberb : Member → Bool
  | .face _ => true
  | .range _ _ => true
  | .amp => false
  | .fold _ => false
  | .sub op => exactNodeb op
  | .prod fs => exactFactorsb fs
def exactNodeb : Node → Bool
  | .nil => true
  | .cons m rest => exactMemberb m && exactNodeb rest
def exactFactorsb : Factors → Bool
  | .nil => true
  | .amp _ => false
  | .node n rest => (exactNodeb n && !(bindsb n)) && exactFactorsb rest
end

/- The sound fragment: `&` reads and closures are fine, folds are fine, but
every subtraction operand must be exact. -/
mutual
def sndMemberb : Member → Bool
  | .face _ => true
  | .range _ _ => true
  | .amp => true
  | .fold inner => sndNodeb inner
  | .sub op => exactNodeb op
  | .prod fs => sndFactorsb fs
def sndNodeb : Node → Bool
  | .nil => true
  | .cons m rest => sndMemberb m && sndNodeb rest
def sndFactorsb : Factors → Bool
  | .nil => true
  | .amp rest => sndFactorsb rest
  | .node n rest => sndNodeb n && sndFactorsb rest
end

/- ---------------------------------------------------------------- -/
/- Two-sided correctness on the exact fragment.                      -/
/- ---------------------------------------------------------------- -/

mutual
theorem exact_member : ∀ (m : Member), exactMemberb m = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (Pb : Bool) (P : Prop) (s : Spelling),
    (Pb = true ↔ P) →
    (walkb (nsingle m) ampb Pb s = true ↔ walk (nsingle m) amp P s)
  | .face t, _, _, _, _, _, _, hacc => by
      rw [walkb_single_face, walk_single_face]; simp [hacc]
  | .range lo hi, _, _, _, _, _, _, hacc => by
      rw [walkb_single_range, walk_single_range]; simp [hacc]
  | .amp, hx, _, _, _, _, _, _ => by simp [exactMemberb] at hx
  | .fold _, hx, _, _, _, _, _, _ => by simp [exactMemberb] at hx
  | .sub op, hx, ampb, amp, Pb, P, s, hacc => by
      simp only [exactMemberb] at hx
      have hop := exact_node op hx ampb amp false False s (by simp)
      rw [walkb_single_sub, walk_single_sub, Bool.and_eq_true, hacc]
      constructor
      · rintro ⟨hp, hn⟩
        refine ⟨hp, ?_⟩
        intro hw
        rw [hop.mpr hw] at hn
        simp at hn
      · rintro ⟨hp, hn⟩
        refine ⟨hp, ?_⟩
        cases hw : walkb op ampb false s with
        | true => exact absurd (hop.mp hw) hn
        | false => rfl
  | .prod fs, hx, ampb, amp, Pb, P, s, hacc => by
      simp only [exactMemberb] at hx
      rw [walkb_single_prod, walk_single_prod, Bool.or_eq_true, hacc,
        exact_factors fs hx ampb amp s]
theorem exact_node : ∀ (n : Node), exactNodeb n = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (Pb : Bool) (P : Prop) (s : Spelling),
    (Pb = true ↔ P) → (walkb n ampb Pb s = true ↔ walk n amp P s)
  | .nil, _, _, _, _, _, _, hacc => by simp only [walkb, walk]; exact hacc
  | .cons m rest, hx, ampb, amp, Pb, P, s, hacc => by
      simp only [exactNodeb, Bool.and_eq_true] at hx
      rw [walkb_cons, walk_cons]
      exact exact_node rest hx.2 ampb amp _ _ s
        (exact_member m hx.1 ampb amp Pb P s hacc)
theorem exact_factors : ∀ (fs : Factors), exactFactorsb fs = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (s : Spelling),
    (fsplitb fs ampb s = true ↔ fsplit fs amp s)
  | .nil, _, _, _, _ => by rw [fsplitb_fnil, fsplit_fnil, isNilb_true_iff]
  | .amp _, hx, _, _, _ => by simp [exactFactorsb] at hx
  | .node n rest, hx, ampb, amp, s => by
      simp only [exactFactorsb, Bool.and_eq_true] at hx
      obtain ⟨⟨hn, hb0⟩, hf⟩ := hx
      have hb : bindsb n = false := by simpa using hb0
      rw [fsplitb_fnode, cuts_true_iff, fsplit_fnode]
      constructor
      · rintro ⟨p, q, rfl, h1, h2⟩
        rw [fcontainsb_nonbinder n ampb p hb] at h1
        exact ⟨p, q, rfl, (ndenote_nonbinder n amp p hb).mpr
          ((exact_node n hn ampb amp false False p (by simp)).mp h1),
          (exact_factors rest hf ampb amp q).mp h2⟩
      · rintro ⟨p, q, rfl, h1, h2⟩
        rw [ndenote_nonbinder n amp p hb] at h1
        exact ⟨p, q, rfl,
          by rw [fcontainsb_nonbinder n ampb p hb]
             exact (exact_node n hn ampb amp false False p (by simp)).mpr h1,
          (exact_factors rest hf ampb amp q).mpr h2⟩
end

/- ---------------------------------------------------------------- -/
/- Soundness on the sndb fragment.                                    -/
/- ---------------------------------------------------------------- -/

/-- Stage soundness follows from body soundness alone: stage k's amp is
stage k-1, whose soundness is the induction hypothesis. -/
theorem stage_sound_of (n : Node)
    (hw : ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (Pb : Bool) (P : Prop)
      (s : Spelling), (∀ t, ampb t = true → amp t) → (Pb = true → P) →
      walkb n ampb Pb s = true → walk n amp P s) :
    ∀ (k : Nat) (s : Spelling), stageb n k s = true → stage n k s
  | 0, s, h => by rw [stageb_zero] at h; simp at h
  | (k + 1), s, h => by
      rw [stageb_succ, Bool.or_eq_true] at h
      rw [stage_succ]
      rcases h with h | h
      · exact Or.inl (stage_sound_of n hw k s h)
      · exact Or.inr (hw (stageb n k) (stage n k) false False s
          (fun t ht => stage_sound_of n hw k t ht) (by simp) h)

mutual
theorem snd_member : ∀ (m : Member), sndMemberb m = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (Pb : Bool) (P : Prop) (s : Spelling),
    (∀ t, ampb t = true → amp t) → (Pb = true → P) →
    walkb (nsingle m) ampb Pb s = true → walk (nsingle m) amp P s
  | .face t, _, _, _, _, _, _, _, hacc, h => by
      rw [walkb_single_face, Bool.or_eq_true] at h
      rw [walk_single_face]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · exact Or.inr (by simpa using h)
  | .range lo hi, _, _, _, _, _, _, _, hacc, h => by
      rw [walkb_single_range, Bool.or_eq_true] at h
      rw [walk_single_range]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · exact Or.inr h
  | .amp, _, ampb, amp, _, _, s, hamp, hacc, h => by
      rw [walkb_single_amp, Bool.or_eq_true] at h
      rw [walk_single_amp]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · exact Or.inr (hamp s h)
  | .fold inner, hx, ampb, amp, Pb, P, s, hamp, hacc, h => by
      simp only [sndMemberb] at hx
      rw [walkb_single_fold, Bool.or_eq_true] at h
      rw [walk_single_fold]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · refine Or.inr ?_
        by_cases hbi : bindsb inner = true
        · rw [spells_fold_binder inner amp s hbi]
          rw [spellsb_fold_binder inner ampb s hbi] at h
          exact ⟨s.length + 1, stage_sound_of inner (snd_node inner hx) (s.length + 1) s h⟩
        · have hb : bindsb inner = false := Bool.eq_false_iff.mpr hbi
          rw [fold_membership inner amp s hb]
          rw [spellsb_fold_nonbinder inner ampb s hb, Bool.or_eq_true,
            Bool.and_eq_true] at h
          rcases h with h | ⟨h1, h2⟩
          · exact Or.inl (snd_node inner hx ampb amp false False s hamp (by simp) h)
          · rw [isNilb_true_iff] at h1
            have h2' : addsb inner = false := by simpa using h2
            exact Or.inr ⟨h1, fun t ht => subs_only_walk inner amp t False h2' ht⟩
  | .sub op, hx, ampb, amp, Pb, P, s, _, hacc, h => by
      simp only [sndMemberb] at hx
      rw [walkb_single_sub, Bool.and_eq_true] at h
      rw [walk_single_sub]
      refine ⟨hacc h.1, ?_⟩
      intro hw
      have hb := (exact_node op hx ampb amp false False s (by simp)).mpr hw
      rw [hb] at h; simp at h
  | .prod fs, hx, ampb, amp, Pb, P, s, hamp, hacc, h => by
      simp only [sndMemberb] at hx
      rw [walkb_single_prod, Bool.or_eq_true] at h
      rw [walk_single_prod]
      rcases h with h | h
      · exact Or.inl (hacc h)
      · exact Or.inr (snd_factors fs hx ampb amp s hamp h)
theorem snd_node : ∀ (n : Node), sndNodeb n = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (Pb : Bool) (P : Prop) (s : Spelling),
    (∀ t, ampb t = true → amp t) → (Pb = true → P) →
    walkb n ampb Pb s = true → walk n amp P s
  | .nil, _, _, _, _, _, _, _, hacc, h => by
      simp only [walkb] at h; simp only [walk]; exact hacc h
  | .cons m rest, hx, ampb, amp, Pb, P, s, hamp, hacc, h => by
      simp only [sndNodeb, Bool.and_eq_true] at hx
      rw [walkb_cons] at h
      rw [walk_cons]
      exact snd_node rest hx.2 ampb amp _ _ s hamp
        (fun hpb => snd_member m hx.1 ampb amp Pb P s hamp hacc hpb) h
theorem snd_factors : ∀ (fs : Factors), sndFactorsb fs = true →
    ∀ (ampb : Spelling → Bool) (amp : Spelling → Prop) (s : Spelling),
    (∀ t, ampb t = true → amp t) → fsplitb fs ampb s = true → fsplit fs amp s
  | .nil, _, _, _, _, _, h => by
      rw [fsplitb_fnil, isNilb_true_iff] at h; rw [fsplit_fnil]; exact h
  | .amp rest, hx, ampb, amp, s, hamp, h => by
      simp only [sndFactorsb] at hx
      rw [fsplitb_famp, cuts_true_iff] at h
      rw [fsplit_famp]
      obtain ⟨p, q, rfl, h1, h2⟩ := h
      exact ⟨p, q, rfl, hamp p h1, snd_factors rest hx ampb amp q hamp h2⟩
  | .node n rest, hx, ampb, amp, s, hamp, h => by
      simp only [sndFactorsb, Bool.and_eq_true] at hx
      obtain ⟨hn, hf⟩ := hx
      rw [fsplitb_fnode, cuts_true_iff] at h
      rw [fsplit_fnode]
      obtain ⟨p, q, rfl, h1, h2⟩ := h
      refine ⟨p, q, rfl, ?_, snd_factors rest hf ampb amp q hamp h2⟩
      cases hb : bindsb n with
      | true =>
          rw [fcontainsb_binder n ampb p hb] at h1
          rw [ndenote_binder n amp p hb]
          exact ⟨p.length + 1, stage_sound_of n (snd_node n hn) (p.length + 1) p h1⟩
      | false =>
          rw [fcontainsb_nonbinder n ampb p hb] at h1
          rw [ndenote_nonbinder n amp p hb]
          exact snd_node n hn ampb amp false False p hamp (by simp) h1
end

/- ---------------------------------------------------------------- -/
/- The headline theorem: on the sound fragment, whatever containsb    -/
/- asserts, the universe denotationally wears.                        -/
/- ---------------------------------------------------------------- -/

theorem containsb_sound (n : Node) (s : Spelling)
    (hs : sndNodeb n = true) (h : containsb n s = true) : denotes n s := by
  rw [denotes]
  cases hb : bindsb n with
  | true =>
      rw [ndenote_binder n _ s hb]
      refine ⟨s.length + 1, stage_sound_of n (snd_node n hs) (s.length + 1) s ?_⟩
      simpa [containsb, hb] using h
  | false =>
      rw [ndenote_nonbinder n _ s hb]
      have h' : walkb n (fun _ => false) false s = true := by simpa [containsb, hb] using h
      exact snd_node n hs (fun _ => false) (fun _ => False) false False s
        (by simp) (by simp) h'

end L1
