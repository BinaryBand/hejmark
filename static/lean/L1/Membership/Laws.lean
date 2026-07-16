/- L1 membership laws: the compression laws and constructor identities of
`docs/foundation/L1.md`, proved at the membership level.

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

/-- Exponent down to `A^0`: the empty factor run is the unit -- it wears
exactly the empty spelling, so `A^0` is well-formed and contributes nothing. -/
theorem exponent_zero (amp : Spelling → Prop) (s : Spelling) :
    spells (.prod .nil) amp s ↔ s = [] := by
  rw [spells_prod, fsplit_fnil]

/- ---------------------------------------------------------------- -/
/- 8. Fold membership, and depth flattening on the doc's shapes.      -/
/- ---------------------------------------------------------------- -/

theorem fold_membership (inner : Node) (amp : Spelling → Prop) (s : Spelling)
    (hb : bindsb inner = false) :
    spells (.fold inner) amp s
      ↔ (walk inner amp False s ∨ (s = [] ∧ ∀ t, ¬ walk inner amp False t)) := by
  rw [spells_fold, hb]; simp

/-- A fold of a fold splices: `{{X}}` wears what `{X}` wears, for non-binder X.
The doc's depth-flattening shape inside a larger member list
(`{a,{b,{c,C}}}` = `{a,{b,c,C}}`) is `fold_flatten_nested` below. -/
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

/-- Depth flattening on the doc's exact shape: `{a,{b,{c,C}}}` = `{a,{b,c,C}}`.
Both sides wear exactly the four faces: the inner folds are nonempty, so the
fold-to-unit branch never fires, and a nested fold splices its universe's
spellings into the enclosing member list. -/
theorem fold_flatten_nested (t1 t2 t3 t4 s : Spelling) :
    denotes (.cons (.face t1) (nsingle (.fold
        (.cons (.face t2) (nsingle (.fold
          (.cons (.face t3) (nsingle (.face t4))))))))) s
      ↔ denotes (.cons (.face t1) (nsingle (.fold
          (.cons (.face t2) (.cons (.face t3) (nsingle (.face t4))))))) s := by
  have hw2 : ∀ (amp : Spelling → Prop) (u : Spelling),
      walk (.cons (.face t3) (nsingle (.face t4))) amp False u ↔ (u = t3 ∨ u = t4) := by
    intro amp u
    simp only [walk_cons, walk_single_face]
    tauto
  have hs2 : ∀ (amp : Spelling → Prop) (u : Spelling),
      spells (.fold (.cons (.face t3) (nsingle (.face t4)))) amp u
        ↔ (u = t3 ∨ u = t4) := by
    intro amp u
    rw [fold_membership _ _ _ (by simp [bindsb, freeAmpb, nsingle])]
    constructor
    · rintro (h | ⟨rfl, hall⟩)
      · exact (hw2 amp u).mp h
      · exact absurd ((hw2 amp t3).mpr (Or.inl rfl)) (hall t3)
    · intro h
      exact Or.inl ((hw2 amp u).mpr h)
  have hw3L : ∀ (amp : Spelling → Prop) (u : Spelling),
      walk (.cons (.face t2) (nsingle (.fold
        (.cons (.face t3) (nsingle (.face t4)))))) amp False u
        ↔ (u = t2 ∨ u = t3 ∨ u = t4) := by
    intro amp u
    simp only [walk_cons, walk_single_fold, walk_single_face, hs2 amp u]
    tauto
  have hw3R : ∀ (amp : Spelling → Prop) (u : Spelling),
      walk (.cons (.face t2) (.cons (.face t3) (nsingle (.face t4)))) amp False u
        ↔ (u = t2 ∨ u = t3 ∨ u = t4) := by
    intro amp u
    simp only [walk_cons, walk_single_face]
    tauto
  have hsL : ∀ (amp : Spelling → Prop) (u : Spelling),
      spells (.fold (.cons (.face t2) (nsingle (.fold
        (.cons (.face t3) (nsingle (.face t4))))))) amp u
        ↔ (u = t2 ∨ u = t3 ∨ u = t4) := by
    intro amp u
    rw [fold_membership _ _ _ (by simp [bindsb, freeAmpb, nsingle])]
    constructor
    · rintro (h | ⟨rfl, hall⟩)
      · exact (hw3L amp u).mp h
      · exact absurd ((hw3L amp t2).mpr (Or.inl rfl)) (hall t2)
    · intro h
      exact Or.inl ((hw3L amp u).mpr h)
  have hsR : ∀ (amp : Spelling → Prop) (u : Spelling),
      spells (.fold (.cons (.face t2) (.cons (.face t3) (nsingle (.face t4))))) amp u
        ↔ (u = t2 ∨ u = t3 ∨ u = t4) := by
    intro amp u
    rw [fold_membership _ _ _ (by simp [bindsb, freeAmpb, nsingle])]
    constructor
    · rintro (h | ⟨rfl, hall⟩)
      · exact (hw3R amp u).mp h
      · exact absurd ((hw3R amp t2).mpr (Or.inl rfl)) (hall t2)
    · intro h
      exact Or.inl ((hw3R amp u).mpr h)
  rw [denotes, denotes,
    ndenote_nonbinder _ _ _ (by simp [bindsb, freeAmpb, nsingle]),
    ndenote_nonbinder _ _ _ (by simp [bindsb, freeAmpb, nsingle])]
  simp only [walk_cons, walk_single_fold, walk_single_face, hsL _ s, hsR _ s]

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

/- ---------------------------------------------------------------- -/
/- 11. Final segment demotion: the closure of the unit under a       -/
/-     literal code-point range wears exactly the spellings over     -/
/-     that range -- the doc's `{{{}}, &C}`, with `C = {lo..hi}`.    -/
/-     "The spelling order is generated, not postulated", at the     -/
/-     membership level.                                              -/
/- ---------------------------------------------------------------- -/

/-- `{{{}}, &{lo..hi}}`: the unit seeds the empty spelling, and each closure
pass appends one code of `C = {lo..hi}` on the right. -/
def unitClosure (lo hi : Code) : Node :=
  .cons (.fold .nil)
    (.cons (.prod (.amp (.node (.cons (.range lo hi) .nil) .nil))) .nil)

theorem unitClosure_bindsb (lo hi : Code) : bindsb (unitClosure lo hi) = true := by
  simp [unitClosure, bindsb, freeAmpb, hasAmpb]

/-- One closure pass of the body: the unit's empty spelling, or an ambient
spelling extended by one in-range code on the right. -/
theorem unitClosure_walk (lo hi : Code) (amp : Spelling → Prop) (s : Spelling) :
    walk (unitClosure lo hi) amp False s
      ↔ s = [] ∨ ∃ p c, s = p ++ [c] ∧ amp p ∧ lo ≤ c ∧ c ≤ hi := by
  rw [unitClosure, walk_cons, walk_cons, walk_nil, walk_single_prod,
    walk_single_fold, unit_spells, fsplit_famp]
  constructor
  · rintro ((h | h) | ⟨p, q, rfl, hp, hq⟩)
    · exact h.elim
    · exact Or.inl h
    · right
      rw [fsplit_fnode] at hq
      obtain ⟨p2, q2, rfl, hp2, hq2⟩ := hq
      rw [fsplit_fnil] at hq2
      subst hq2
      rw [ndenote_nonbinder _ _ _ (by simp [bindsb, freeAmpb]),
        walk_cons, walk_nil, walk_single_range] at hp2
      rcases hp2 with h | h
      · exact h.elim
      · rw [winb_range_singleton] at h
        obtain ⟨c, rfl, hc1, hc2⟩ := h
        exact ⟨p, c, by simp, hp, hc1, hc2⟩
  · rintro (rfl | ⟨p, c, rfl, hp, hc1, hc2⟩)
    · exact Or.inl (Or.inr rfl)
    · refine Or.inr ⟨p, [c], rfl, hp, ?_⟩
      rw [fsplit_fnode]
      refine ⟨[c], [], by simp, ?_, by rw [fsplit_fnil]⟩
      rw [ndenote_nonbinder _ _ _ (by simp [bindsb, freeAmpb]),
        walk_cons, walk_nil, walk_single_range]
      right
      rw [winb_range_singleton]
      exact ⟨c, rfl, hc1, hc2⟩

/-- Soundness: every closure stage stays over `C`. -/
theorem unitClosure_stage_sound (lo hi : Code) :
    ∀ k s, stage (unitClosure lo hi) k s → ∀ c ∈ s, lo ≤ c ∧ c ≤ hi := by
  intro k
  induction k with
  | zero => intro s h; rw [stage_zero] at h; exact h.elim
  | succ k ih =>
      intro s h
      rw [stage_succ] at h
      rcases h with h | h
      · exact ih s h
      · rw [unitClosure_walk] at h
        rcases h with rfl | ⟨p, c, rfl, hp, hc1, hc2⟩
        · intro c hc; simp at hc
        · intro x hx
          rw [List.mem_append] at hx
          rcases hx with hx | hx
          · exact ih p hp x hx
          · simp only [List.mem_singleton] at hx
            subst hx
            exact ⟨hc1, hc2⟩

/-- Completeness: a spelling of length `L` over `C` is present by stage
`L + 1` -- each pass appends one code, seeded by the unit's empty face. -/
theorem unitClosure_stage_complete (lo hi : Code) :
    ∀ s : Spelling, (∀ c ∈ s, lo ≤ c ∧ c ≤ hi) →
      stage (unitClosure lo hi) (s.length + 1) s := by
  intro s
  induction s using List.reverseRecOn with
  | nil =>
      intro _
      rw [stage_succ]
      exact Or.inr ((unitClosure_walk lo hi _ []).mpr (Or.inl rfl))
  | append_singleton p c ih =>
      intro h
      rw [stage_succ]
      right
      rw [unitClosure_walk]
      refine Or.inr ⟨p, c, rfl, ?_, (h c (by simp)).1, (h c (by simp)).2⟩
      have hp := ih (fun x hx => h x (by simp [hx]))
      simpa using hp

/-- The demotion law, two-sided: `{{{}}, &{lo..hi}}` denotes exactly the
spellings whose every code sits in `[lo, hi]`, the empty spelling included.
This is the membership content of re-admitting the final segment as
compression: the closure generates every spelling over the code-point set. -/
theorem unitClosure_generates (lo hi : Code) (s : Spelling) :
    denotes (unitClosure lo hi) s ↔ ∀ c ∈ s, lo ≤ c ∧ c ≤ hi := by
  rw [denotes, ndenote_binder _ _ _ (unitClosure_bindsb lo hi)]
  constructor
  · rintro ⟨k, hk⟩
    exact unitClosure_stage_sound lo hi k s hk
  · intro h
    exact ⟨s.length + 1, unitClosure_stage_complete lo hi s h⟩

end L1
