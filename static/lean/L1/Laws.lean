/- L1 membership laws: the compression laws and constructor identities of
`docs/foundation/L1_TEMP.md`, proved at the membership level.

Port of `static/formal/L1/Laws.v`. Everything here is about which spellings a
universe wears; the order axis (entry order, positional value) is out of scope.
In particular the doc's "union is not commutative" is a statement about entry
order; at the membership level union is a commutative, idempotent, associative
join (items 2a-2c). -/
import L1.Semantics

namespace L1

/- ---------------------------------------------------------------- -/
/- 1. Walk decomposition: the walk is a left fold, so union composes -/
/-    accumulators.                                                  -/
/- ---------------------------------------------------------------- -/

theorem walk_app : ∀ (n1 n2 : Node) (amp : Spelling → Prop) (P : Prop) (s : Spelling),
    walk (napp n1 n2) amp P s = walk n2 amp (walk n1 amp P s) s
  | .nil, n2, amp, P, s => by simp only [napp, walk]
  | .cons m rest, n2, amp, P, s => by
      simp only [napp]
      rw [walk_cons, walk_app rest n2 amp (walk (nsingle m) amp P s) s,
        walk_cons m rest]

/- ---------------------------------------------------------------- -/
/- 2. Union: associative, and on subtraction-free member lists       -/
/-    idempotent and commutative at the membership level.            -/
/- ---------------------------------------------------------------- -/

/-- The spellings some member of a subtraction-free list wears. -/
def anyspell : Node → (Spelling → Prop) → Spelling → Prop
  | .nil, _, _ => False
  | .cons m rest, amp, s => spells m amp s ∨ anyspell rest amp s

theorem walk_adds : ∀ (n : Node) (amp : Spelling → Prop) (P : Prop) (s : Spelling),
    subfreeb n = true → (walk n amp P s ↔ P ∨ anyspell n amp s)
  | .nil, amp, P, s, _ => by simp only [walk, anyspell]; tauto
  | .cons m rest, amp, P, s, hsf => by
      cases m with
      | sub op => simp [subfreeb] at hsf
      | _ =>
          rw [walk_cons, walk_adds rest amp _ s (by simpa [subfreeb] using hsf)]
          simp only [nsingle, walk, anyspell]
          tauto

theorem union_idem (n : Node) (amp : Spelling → Prop) (P : Prop) (s : Spelling)
    (hsf : subfreeb n = true) :
    walk (napp n n) amp P s ↔ walk n amp P s := by
  rw [walk_app, walk_adds n amp (walk n amp P s) s hsf, walk_adds n amp P s hsf]
  tauto

theorem union_comm (n1 n2 : Node) (amp : Spelling → Prop) (P : Prop) (s : Spelling)
    (h1 : subfreeb n1 = true) (h2 : subfreeb n2 = true) :
    walk (napp n1 n2) amp P s ↔ walk (napp n2 n1) amp P s := by
  rw [walk_app, walk_app,
    walk_adds n2 amp (walk n1 amp P s) s h2, walk_adds n1 amp P s h1,
    walk_adds n1 amp (walk n2 amp P s) s h1, walk_adds n2 amp P s h2]
  tauto

theorem denotes_union_idem (n : Node) (s : Spelling)
    (hsf : subfreeb n = true) (hb : bindsb n = false) :
    denotes (napp n n) s ↔ denotes n s := by
  simp only [denotes, ndenote, bindsb_napp, hb, Bool.or_self, Bool.false_eq_true,
    if_false]
  exact union_idem n (fun _ => False) False s hsf

/- ---------------------------------------------------------------- -/
/- 3. Difference: appending a subtraction is set difference.         -/
/- ---------------------------------------------------------------- -/

theorem difference (A B : Node) (amp : Spelling → Prop) (P : Prop) (s : Spelling) :
    walk (napp A (nsingle (.sub B))) amp P s
      ↔ (walk A amp P s ∧ ¬ walk B amp False s) := by
  rw [walk_app, walk_single_sub]

/- ---------------------------------------------------------------- -/
/- 4. Intersection: A ∧ B = A \ (A \ B). Classical (tauto uses em     -/
/-    on B's membership); the development is classical throughout.   -/
/- ---------------------------------------------------------------- -/

theorem intersection (A B : Node) (amp : Spelling → Prop) (s : Spelling) :
    walk (napp A (nsingle (.sub (napp A (nsingle (.sub B)))))) amp False s
      ↔ (walk A amp False s ∧ walk B amp False s) := by
  rw [difference, difference]
  tauto

/- ---------------------------------------------------------------- -/
/- 5. Bounded ranges are compression: {lo..hi} = {lo.., !{succ hi..}} -/
/- ---------------------------------------------------------------- -/

theorem range_compression (lo hi : Code) (amp : Spelling → Prop) (s : Spelling) :
    walk (.cons (.final [lo]) (nsingle (.sub (nsingle (.final [hi + 1]))))) amp False s
      ↔ spells (.range lo hi) amp s := by
  rw [show (Node.cons (.final [lo]) (nsingle (.sub (nsingle (.final [hi + 1])))))
        = napp (nsingle (.final [lo])) (nsingle (.sub (nsingle (.final [hi + 1])))) from rfl,
    difference, walk_single_final, walk_single_final]
  simp only [false_or, spells, ← winb_range_diff lo hi s, finalWindow]
  cases winb ⟨[lo], none⟩ s <;> cases winb ⟨[hi + 1], none⟩ s <;> simp

theorem range_reversed_empty (lo hi : Code) (amp : Spelling → Prop) (s : Spelling)
    (hrev : hi < lo) : ¬ spells (.range lo hi) amp s := by
  rw [spells]
  rw [winb_range_empty lo hi s hrev]
  simp

/- ---------------------------------------------------------------- -/
/- 6. Finite adjacency: {t1}{t2} = {t1 ++ t2}.                        -/
/- ---------------------------------------------------------------- -/

theorem ndenote_nonbinder (n : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb n = false) : ndenote n amp s ↔ walk n amp False s := by
  simp [ndenote, hb]

theorem ndenote_binder (n : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb n = true) : ndenote n amp s ↔ ∃ k, stage n k s := by
  simp [ndenote, hb]

theorem ndenote_face (t : Spelling) (amp : Spelling → Prop) (p : Spelling) :
    ndenote (nsingle (.face t)) amp p ↔ p = t := by
  rw [ndenote_nonbinder _ _ _ (by rfl), walk_single_face]
  simp

theorem adjacency (t1 t2 : Spelling) (amp : Spelling → Prop) (s : Spelling) :
    spells (.prod (.node (nsingle (.face t1)) (.node (nsingle (.face t2)) .nil))) amp s
      ↔ spells (.face (t1 ++ t2)) amp s := by
  rw [spells_prod, fsplit_fnode, spells]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    rw [fsplit_fnode] at hq
    obtain ⟨p', q', rfl, hp', hq'⟩ := hq
    rw [fsplit_fnil] at hq'
    rw [ndenote_face] at hp hp'
    subst hp; subst hp'; subst hq'
    simp
  · rintro rfl
    refine ⟨t1, t2 ++ [], by simp, ?_, ?_⟩
    · rw [ndenote_face]
    · rw [fsplit_fnode]
      exact ⟨t2, [], by simp, by rw [ndenote_face], by rw [fsplit_fnil]⟩

/- ---------------------------------------------------------------- -/
/- 7. The empty universe and the unit.                                -/
/- ---------------------------------------------------------------- -/

theorem empty_denotes (s : Spelling) : ¬ denotes .nil s := by
  simp [denotes, ndenote, bindsb, walk]

theorem unit_spells (amp : Spelling → Prop) (s : Spelling) :
    spells (.fold .nil) amp s ↔ s = [] := by
  rw [spells_fold]
  simp [bindsb, walk]

def unitNode : Node := nsingle (.fold .nil)

theorem unit_ndenote (amp : Spelling → Prop) (p : Spelling) :
    ndenote unitNode amp p ↔ p = [] := by
  rw [unitNode, ndenote_nonbinder _ _ _ (by rfl), walk_single_fold, unit_spells]
  simp

theorem product_unit_l (A : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb A = false) :
    spells (.prod (.node unitNode (.node A .nil))) amp s ↔ walk A amp False s := by
  rw [spells_prod, fsplit_fnode]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    rw [unit_ndenote] at hp; subst hp
    rw [fsplit_fnode] at hq
    obtain ⟨p', q', rfl, hp', hq'⟩ := hq
    rw [fsplit_fnil] at hq'; subst hq'
    rw [ndenote_nonbinder _ _ _ hb] at hp'
    simpa using hp'
  · intro h
    refine ⟨[], s, by simp, by rw [unit_ndenote], ?_⟩
    rw [fsplit_fnode]
    exact ⟨s, [], by simp, by rw [ndenote_nonbinder _ _ _ hb]; exact h, by rw [fsplit_fnil]⟩

theorem product_unit_r (A : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb A = false) :
    spells (.prod (.node A (.node unitNode .nil))) amp s ↔ walk A amp False s := by
  rw [spells_prod, fsplit_fnode]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    rw [fsplit_fnode] at hq
    obtain ⟨p', q', rfl, hp', hq'⟩ := hq
    rw [fsplit_fnil] at hq'; subst hq'
    rw [unit_ndenote] at hp'; subst hp'
    rw [ndenote_nonbinder _ _ _ hb] at hp
    simpa using hp
  · intro h
    refine ⟨s, [], by simp, by rw [ndenote_nonbinder _ _ _ hb]; exact h, ?_⟩
    rw [fsplit_fnode]
    exact ⟨[], [], by simp, by rw [unit_ndenote], by rw [fsplit_fnil]⟩

/- ---------------------------------------------------------------- -/
/- 8. Fold membership, and depth flattening on the doc's shapes.      -/
/- ---------------------------------------------------------------- -/

theorem fold_membership (inner : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb inner = false) :
    spells (.fold inner) amp s
      ↔ (walk inner amp False s ∨ (s = [] ∧ ∀ t, ¬ walk inner amp False t)) := by
  rw [spells_fold, hb]; simp

/-- A fold of a fold splices: `{{X}}` wears what `{X}` wears, for non-binder X.
Scope note: this is the singleton shape only; the doc's full depth-flattening
claim (`{a,{b,{c,C}}}` = `{a,{b,c,C}}`, flattening inside a larger member
list) is not yet mechanized. -/
theorem fold_flatten (inner : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb inner = false) :
    spells (.fold (nsingle (.fold inner))) amp s ↔ spells (.fold inner) amp s := by
  have houter : bindsb (nsingle (.fold inner)) = false := by simp [nsingle, bindsb, freeAmpb]
  rw [fold_membership (nsingle (.fold inner)) amp s houter]
  constructor
  · rintro (h | ⟨_, hempty⟩)
    · rw [walk_single_fold] at h
      rcases h with h | h
      · exact absurd h id
      · exact h
    · exfalso
      have hnil : ¬ walk (nsingle (.fold inner)) amp False [] := hempty []
      rw [walk_single_fold] at hnil
      apply hnil; right
      rw [fold_membership inner amp [] hb]
      refine Or.inr ⟨rfl, ?_⟩
      intro t ht
      apply hempty t
      rw [walk_single_fold]; right
      rw [fold_membership inner amp t hb]
      exact Or.inl ht
  · intro h
    left; rw [walk_single_fold]; right; exact h

/- ---------------------------------------------------------------- -/
/- 10. Bare-`&` no-ops, as general equivalences.                      -/
/- ---------------------------------------------------------------- -/

/-- `{&}`: a bare self-reference builds nothing. -/
theorem bare_amp_empty (s : Spelling) : ¬ denotes (nsingle .amp) s := by
  have hstage : ∀ k s, ¬ stage (nsingle .amp) k s := by
    intro k
    induction k with
    | zero => intro s h; rw [stage_zero] at h; exact h
    | succ k ih =>
        intro s h
        rw [stage_succ] at h
        rcases h with h | h
        · exact ih s h
        · rw [walk_single_amp] at h
          rcases h with h | h
          · exact h.elim
          · exact ih s h
  intro hd
  rw [denotes, ndenote_binder _ _ _ (by simp [nsingle, bindsb, freeAmpb])] at hd
  obtain ⟨k, h⟩ := hd
  exact hstage k s h

/-- `{a, &}`: self-union no-ops. -/
theorem self_union_noop (t : Spelling) (s : Spelling) :
    denotes (.cons (.face t) (nsingle .amp)) s ↔ s = t := by
  set n := Node.cons (.face t) (nsingle .amp) with hn
  have hb : bindsb n = true := by rw [hn]; simp [bindsb, freeAmpb, nsingle]
  have hstage : ∀ k s, stage n k s → s = t := by
    intro k
    induction k with
    | zero => intro s h; rw [stage_zero] at h; exact h.elim
    | succ k ih =>
        intro s h
        rw [stage_succ] at h
        rcases h with h | h
        · exact ih s h
        · rw [hn, walk_cons, walk_single_amp, walk_single_face] at h
          rcases h with (h | h) | h
          · exact h.elim
          · exact h
          · exact ih s h
  constructor
  · rintro hd
    rw [denotes, ndenote_binder _ _ _ hb] at hd
    obtain ⟨k, h⟩ := hd
    exact hstage k s h
  · rintro rfl
    rw [denotes, ndenote_binder _ _ _ hb]
    exact ⟨1, by rw [stage_succ, stage_zero, hn, walk_cons, walk_single_amp,
      walk_single_face]; right; left; right; rfl⟩

/-- `{lo.., !{&}}`: stage 1 places the whole final segment; the closure is
just `{lo..}`. -/
theorem negative_amp_noop (lo : Spelling) (s : Spelling) :
    denotes (.cons (.final lo) (nsingle (.sub (nsingle .amp)))) s
      ↔ winb (finalWindow lo) s = true := by
  set n := Node.cons (.final lo) (nsingle (.sub (nsingle .amp))) with hn
  have hb : bindsb n = true := by rw [hn]; simp [bindsb, freeAmpb, nsingle]
  have hstage : ∀ k s, stage n k s → winb (finalWindow lo) s = true := by
    intro k
    induction k with
    | zero => intro s h; rw [stage_zero] at h; exact h.elim
    | succ k ih =>
        intro s h
        rw [stage_succ] at h
        rcases h with h | h
        · exact ih s h
        · rw [hn, walk_cons, walk_single_final, walk_single_sub] at h
          rcases h.1 with h' | h'
          · exact h'.elim
          · exact h'
  constructor
  · rintro hd
    rw [denotes, ndenote_binder _ _ _ hb] at hd
    obtain ⟨k, h⟩ := hd
    exact hstage k s h
  · rintro h
    rw [denotes, ndenote_binder _ _ _ hb]
    refine ⟨1, ?_⟩
    rw [stage_succ, stage_zero, hn, walk_cons, walk_single_final, walk_single_sub]
    refine Or.inr ⟨Or.inr h, ?_⟩
    rw [walk_single_amp]
    simp [stage_zero]

end L1
