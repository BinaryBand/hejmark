/- L1 north-star table (`docs/foundation/L1.md`), at the membership level.

Port of `static/formal/L1/NorthStar.v`. Positive rows compute through
`containsb_sound`: `sndNodeb` and `containsb` are both closed booleans, so
`native_decide` (compiled) settles them -- the Lean analogue of Coq's
`vm_compute`. Trust base: `native_decide` puts the Lean compiler in the
trusted base for these rows (kernel `decide` cannot replace it -- the
evaluator is well-founded recursion, which does not reduce in the kernel).
The soundness spine (`containsb_sound` and below) and every hand-proved row
here depend on `propext`/`Quot.sound` only. Negative and emptiness rows are
proved at the Prop level (the evaluator is sound, not complete), mostly as
corollaries of `Laws`.

Out of scope here, with the rest of the order axis: every claim about entry
order, values, collision ownership, and order types.

Toy code assignment: letters a..z are 0..25, digits 0..9 are 100..109, and
the parentheses of the binary-trees row are 40 and 41. -/
import L1.Membership.Evaluator

namespace L1

abbrev la : Code := 0
abbrev lb : Code := 1
abbrev lc : Code := 2
abbrev ld : Code := 3
abbrev le : Code := 4
abbrev lf : Code := 5
abbrev lg : Code := 6
abbrev li : Code := 8
abbrev ll : Code := 11
abbrev ln : Code := 13
abbrev lo : Code := 14
abbrev lt : Code := 19
abbrev lu : Code := 20
abbrev lz : Code := 25
abbrev d0 : Code := 100
abbrev d1 : Code := 101
abbrev d5 : Code := 105
abbrev d9 : Code := 109
abbrev lpar : Code := 40
abbrev rpar : Code := 41

abbrev cat : Spelling := [lc, la, lt]
abbrev dog : Spelling := [ld, lo, lg]
abbrev feline : Spelling := [lf, le, ll, li, ln, le]

def nlist : List Member → Node
  | [] => .nil
  | m :: rest => .cons m (nlist rest)

/-- Discharge a positive membership row: both `sndNodeb` and `containsb`
compile to closed booleans. -/
macro "north_star" : tactic =>
  `(tactic| (refine containsb_sound _ _ ?_ ?_ <;> native_decide))

/-- The shared opening of every two-factor non-binder product refutation: a
denoted spelling splits as `p ++ q` with each factor denoting its own piece.
The negative-row counterpart of `north_star`, factoring the fsplit boilerplate
so each `_not_` proof keeps only its factor-specific refutation. -/
theorem two_factor_split {A B : Node} {s : Spelling}
    (h : denotes (nlist [.prod (.node A (.node B .nil))]) s) :
    ∃ p q, s = p ++ q ∧ ndenote A (fun _ => False) p ∧ ndenote B (fun _ => False) q := by
  rw [denotes, ndenote_nonbinder _ _ _ (by simp [nlist, bindsb, freeAmpb, hasAmpb])] at h
  simp only [nlist, walk_cons, walk_single_prod, walk_nil, false_or] at h
  rw [fsplit_fnode] at h
  obtain ⟨p, q, hs, hp, hq⟩ := h
  rw [fsplit_fnode] at hq
  obtain ⟨p2, q2, rfl, hp2, hq2⟩ := hq
  rw [fsplit_fnil] at hq2
  subst hq2
  exact ⟨p, p2, by simpa using hs, hp, hp2⟩

/-- A one-face factor pins its piece: `{w}` hands the split exactly `w`. -/
theorem face_ndenote {w : Spelling} {amp : Spelling → Prop} {q : Spelling}
    (h : ndenote (nlist [.face w]) amp q) : q = w := by
  rw [ndenote_nonbinder _ _ _ (by simp [nlist, bindsb, freeAmpb])] at h
  simpa [nlist, walk_cons, walk_single_face, walk_nil] using h

/-- A two-face factor hands its piece one of its faces. -/
theorem two_face_ndenote {w1 w2 : Spelling} {amp : Spelling → Prop} {q : Spelling}
    (h : ndenote (nlist [.face w1, .face w2]) amp q) : q = w1 ∨ q = w2 := by
  rw [ndenote_nonbinder _ _ _ (by simp [nlist, bindsb, freeAmpb])] at h
  simpa [nlist, walk_cons, walk_single_face, walk_nil] using h

/-- A final-segment factor hands its piece a spelling of its window. -/
theorem final_ndenote {lo : Spelling} {amp : Spelling → Prop} {q : Spelling}
    (h : ndenote (nlist [.final lo]) amp q) : winb (finalWindow lo) q = true := by
  rw [ndenote_nonbinder _ _ _ (by simp [nlist, bindsb, freeAmpb])] at h
  simpa [nlist, walk_cons, walk_single_final, walk_nil] using h

/- ---------------------------------------------------------------- -/
/- {a,b,c}                                                          -/
/- ---------------------------------------------------------------- -/

def abc : Node := nlist [.face [la], .face [lb], .face [lc]]

theorem abc_has_b : denotes abc [lb] := by north_star

theorem abc_not_d : ¬ denotes abc [ld] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [abc, nlist, walk_cons, walk_single_face, walk_nil] at h
  rcases h with ((h | h) | h) | h <;> simp_all

/- ---------------------------------------------------------------- -/
/- {a..z}: both endpoints in, empty and longer spellings out.       -/
/- ---------------------------------------------------------------- -/

def a_to_z : Node := nlist [.range la lz]

theorem a_to_z_has_a : denotes a_to_z [la] := by north_star
theorem a_to_z_has_z : denotes a_to_z [lz] := by north_star

theorem a_to_z_not_empty_spelling : ¬ denotes a_to_z [] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp [a_to_z, nlist, walk_cons, walk_single_range, walk_nil, winb_range_singleton] at h

theorem a_to_z_not_aa : ¬ denotes a_to_z [la, la] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp [a_to_z, nlist, walk_cons, walk_single_range, walk_nil, winb_range_singleton] at h

/- ---------------------------------------------------------------- -/
/- {{cat,feline}}: one entry, faces cat and feline; not the unit.   -/
/- ---------------------------------------------------------------- -/

def cat_feline : Node := nlist [.fold (nlist [.face cat, .face feline])]

theorem cat_feline_has_cat : denotes cat_feline cat := by north_star
theorem cat_feline_has_feline : denotes cat_feline feline := by north_star

theorem cat_feline_not_unit : ¬ denotes cat_feline [] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  rw [cat_feline, nlist, nlist, walk_cons, walk, walk_single_fold] at h
  rcases h with h | h
  · exact h.elim
  · rw [fold_membership _ _ _ (by decide)] at h
    rcases h with h | ⟨_, hempty⟩
    · simp only [nlist, walk_cons, walk_single_face, walk_nil] at h
      rcases h with (h | h) | h <;> simp_all
    · exact (hempty cat) (by
        simp [nlist, walk_cons, walk_single_face, walk_nil])

/- ---------------------------------------------------------------- -/
/- {a..z, !{a,e,i,o,u}}: difference = subtraction.                  -/
/- ---------------------------------------------------------------- -/

def consonants : Node :=
  nlist [.range la lz,
    .sub (nlist [.face [la], .face [le], .face [li], .face [lo], .face [lu]])]

theorem consonants_has_b : denotes consonants [lb] := by north_star

theorem consonants_not_a : ¬ denotes consonants [la] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [consonants, nlist, walk_cons, walk_single_sub, walk_single_range,
    walk_single_face, walk_nil] at h
  refine h.2 ?_
  tauto

/- ---------------------------------------------------------------- -/
/- {{cat,feline}, !{feline}}: subtraction strips a face.            -/
/- ---------------------------------------------------------------- -/

def cat_only : Node :=
  nlist [.fold (nlist [.face cat, .face feline]), .sub (nlist [.face feline])]

theorem cat_only_has_cat : denotes cat_only cat := by north_star

theorem cat_only_not_feline : ¬ denotes cat_only feline := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [cat_only, nlist, walk_cons, walk_single_sub, walk_single_fold,
    walk_single_face, walk_nil] at h
  refine h.2 ?_
  tauto

/- ---------------------------------------------------------------- -/
/- {a..}: a final segment, unbounded above.                        -/
/- ---------------------------------------------------------------- -/

def a_final : Node := nlist [.final [la]]

theorem a_final_has_z : denotes a_final [lz] := by north_star
theorem a_final_has_aa : denotes a_final [la, la] := by north_star

theorem a_final_not_empty_spelling : ¬ denotes a_final [] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [a_final, nlist, walk_cons, walk_single_final, walk_nil] at h
  rcases h with h | h <;> simp_all [winb, shortlexLe, shortlexLt, finalWindow]

/- ---------------------------------------------------------------- -/
/- {cat}{dog} = {catdog}: finite adjacency is compression.          -/
/- ---------------------------------------------------------------- -/

def catdog : Node :=
  nlist [.prod (.node (nlist [.face cat]) (.node (nlist [.face dog]) .nil))]

theorem catdog_row (amp : Spelling → Prop) (s : Spelling) :
    spells (.prod (.node (nlist [.face cat]) (.node (nlist [.face dog]) .nil))) amp s
      ↔ spells (.face (cat ++ dog)) amp s := by
  simpa [nlist, nsingle] using adjacency cat dog amp s

theorem catdog_has_catdog : denotes catdog (cat ++ dog) := by north_star

/- ---------------------------------------------------------------- -/
/- {a,ab}{b,c}: ab, ac, abb, abc.                                   -/
/- ---------------------------------------------------------------- -/

def prod_row : Node :=
  nlist [.prod (.node (nlist [.face [la], .face [la, lb]])
    (.node (nlist [.face [lb], .face [lc]]) .nil))]

theorem prod_row_has_ab : denotes prod_row [la, lb] := by north_star
theorem prod_row_has_ac : denotes prod_row [la, lc] := by north_star
theorem prod_row_has_abb : denotes prod_row [la, lb, lb] := by north_star
theorem prod_row_has_abc : denotes prod_row [la, lb, lc] := by north_star

theorem prod_row_not_abbc : ¬ denotes prod_row [la, lb, lb, lc] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  rcases two_face_ndenote hp with rfl | rfl <;>
    rcases two_face_ndenote hp2 with rfl | rfl <;> simp_all

/- {a,ab}{c,bc}: the full membership set ac, abc, abbc -- the doc's
"(ab,c) re-spells abc" is an ownership drop, and membership survives it. -/

def collision_row : Node :=
  nlist [.prod (.node (nlist [.face [la], .face [la, lb]])
    (.node (nlist [.face [lc], .face [lb, lc]]) .nil))]

theorem collision_row_has_ac : denotes collision_row [la, lc] := by north_star
theorem collision_row_has_abc : denotes collision_row [la, lb, lc] := by north_star
theorem collision_row_has_abbc : denotes collision_row [la, lb, lb, lc] := by north_star

theorem collision_row_not_abbbc : ¬ denotes collision_row [la, lb, lb, lb, lc] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  rcases two_face_ndenote hp with rfl | rfl <;>
    rcases two_face_ndenote hp2 with rfl | rfl <;> simp_all

def final_times_b : Node :=
  nlist [.prod (.node (nlist [.final [la]]) (.node (nlist [.face [lb]]) .nil))]

theorem final_times_b_has_ab : denotes final_times_b [la, lb] := by north_star
theorem final_times_b_has_zb : denotes final_times_b [lz, lb] := by north_star

theorem final_times_b_not_ba : ¬ denotes final_times_b [lb, la] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  obtain rfl := face_ndenote hp2
  rcases p with _ | ⟨x, _ | ⟨y, p⟩⟩ <;> simp_all

/- ---------------------------------------------------------------- -/
/- {b,c}{a..}: order type omega*2 -- membership samples.            -/
/- ---------------------------------------------------------------- -/

def bc_final : Node :=
  nlist [.prod (.node (nlist [.face [lb], .face [lc]])
    (.node (nlist [.final [la]]) .nil))]

theorem bc_final_has_ba : denotes bc_final [lb, la] := by north_star
theorem bc_final_has_ca : denotes bc_final [lc, la] := by north_star

theorem bc_final_not_a : ¬ denotes bc_final [la] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  rcases two_face_ndenote hp with rfl | rfl <;> simp_all

/- ---------------------------------------------------------------- -/
/- {b}{a..}{b}{a..}: order type omega^2 -- membership samples.       -/
/- ---------------------------------------------------------------- -/

def b_final_b_final : Node :=
  nlist [.prod (.node (nlist [.face [lb]])
    (.node (nlist [.final [la]])
    (.node (nlist [.face [lb]])
    (.node (nlist [.final [la]]) .nil))))]

theorem b_final_b_final_has_baba : denotes b_final_b_final [lb, la, lb, la] := by
  north_star
theorem b_final_b_final_has_babb : denotes b_final_b_final [lb, la, lb, lb] := by
  north_star

theorem b_final_b_final_not_bab : ¬ denotes b_final_b_final [lb, la, lb] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [b_final_b_final, nlist, walk_cons, walk_single_prod, walk_nil,
    false_or, fsplit_fnode, fsplit_fnil] at h
  obtain ⟨p1, q1, hs, hp1, p2, q2, rfl, hp2, p3, q3, rfl, hp3, p4, q4, rfl, hp4, rfl⟩ := h
  obtain rfl := face_ndenote hp1
  obtain rfl := face_ndenote hp3
  have l2 := winb_final_length (final_ndenote hp2)
  have l4 := winb_final_length (final_ndenote hp4)
  have hlen := congrArg List.length hs
  simp only [List.length_cons, List.length_append, List.length_nil] at hlen l2 l4
  omega

/- ---------------------------------------------------------------- -/
/- {a..}{a..}: cofinite factors collide, membership stands.          -/
/- ---------------------------------------------------------------- -/

def final_final : Node :=
  nlist [.prod (.node (nlist [.final [la]]) (.node (nlist [.final [la]]) .nil))]

theorem final_final_has_aa : denotes final_final [la, la] := by north_star
theorem final_final_has_ab : denotes final_final [la, lb] := by north_star

theorem final_final_not_a : ¬ denotes final_final [la] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  have l1 := winb_final_length (final_ndenote hp)
  have l2 := winb_final_length (final_ndenote hp2)
  have hlen := congrArg List.length hs
  simp only [List.length_cons, List.length_append, List.length_nil] at hlen l1 l2
  omega

/- ---------------------------------------------------------------- -/
/- {a,!{a}}: the empty universe.                                    -/
/- ---------------------------------------------------------------- -/

def a_minus_a : Node := nlist [.face [la], .sub (nlist [.face [la]])]

theorem a_minus_a_empty (s : Spelling) : ¬ denotes a_minus_a s := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [a_minus_a, nlist, walk_cons, walk_single_face, walk_single_sub,
    walk_nil] at h
  exact h.2 h.1

/- ---------------------------------------------------------------- -/
/- {z..a}: a reversed range is empty.                              -/
/- ---------------------------------------------------------------- -/

def z_to_a : Node := nlist [.range lz la]

theorem z_to_a_empty (s : Spelling) : ¬ denotes z_to_a s := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [z_to_a, nlist, walk_cons, walk_single_range, walk_nil] at h
  rcases h with h | h
  · exact h.elim
  · exact range_reversed_empty lz la (fun _ => False) s (by decide) (by rw [spells]; exact h)

/- ---------------------------------------------------------------- -/
/- {{}}: the unit -- one entry, one face, the empty spelling.       -/
/- ---------------------------------------------------------------- -/

def unit_row : Node := nlist [.fold .nil]

theorem unit_row_has_empty_spelling : denotes unit_row [] := by north_star

theorem unit_row_not_a : ¬ denotes unit_row [la] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  rw [unit_row, nlist, nlist, walk_cons, walk, walk_single_fold] at h
  rcases h with h | h
  · exact h.elim
  · rw [unit_spells] at h; simp_all

/- ---------------------------------------------------------------- -/
/- Fold totality reads the denotation, not the page: {{z..a}} and    -/
/- {{a,!{a}}} are the unit. The evaluator's fold-unit surrogate      -/
/- misses both (the documented divergence), so these rows are        -/
/- Prop-level only, never `north_star`.                              -/
/- ---------------------------------------------------------------- -/

def fold_reversed : Node := nlist [.fold (nlist [.range lz la])]

theorem fold_reversed_is_unit : denotes fold_reversed [] := by
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)]
  simp only [fold_reversed, nlist, walk_cons, walk_single_fold, walk_nil, false_or]
  rw [fold_membership _ _ _ (by decide)]
  refine Or.inr ⟨rfl, ?_⟩
  intro t ht
  simp only [walk_cons, walk_single_range, walk_nil, false_or] at ht
  rw [winb_range_empty lz la t (by decide)] at ht
  simp at ht

theorem fold_reversed_not_a : ¬ denotes fold_reversed [la] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [fold_reversed, nlist, walk_cons, walk_single_fold, walk_nil,
    false_or] at h
  rw [fold_membership _ _ _ (by decide)] at h
  rcases h with h | ⟨h, _⟩
  · simp only [walk_cons, walk_single_range, walk_nil, false_or] at h
    rw [winb_range_empty lz la _ (by decide)] at h
    simp at h
  · simp at h

def fold_sub : Node := nlist [.fold a_minus_a]

theorem fold_sub_is_unit : denotes fold_sub [] := by
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)]
  simp only [fold_sub, nlist, walk_cons, walk_single_fold, walk_nil, false_or]
  rw [fold_membership _ _ _ (by decide)]
  refine Or.inr ⟨rfl, ?_⟩
  intro t ht
  simp only [a_minus_a, nlist, walk_cons, walk_single_face, walk_single_sub,
    walk_nil] at ht
  exact ht.2 ht.1

theorem fold_sub_not_a : ¬ denotes fold_sub [la] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [fold_sub, nlist, walk_cons, walk_single_fold, walk_nil,
    false_or] at h
  rw [fold_membership _ _ _ (by decide)] at h
  rcases h with h | ⟨h, _⟩
  · simp only [a_minus_a, nlist, walk_cons, walk_single_face, walk_single_sub,
      walk_nil] at h
    exact h.2 h.1
  · simp at h

/- ---------------------------------------------------------------- -/
/- {{{},0}}: the fill factor -- faces `` and `0`.                   -/
/- ---------------------------------------------------------------- -/

def fill_body : Node := nlist [.fold .nil, .face [d0]]
def fill : Node := nlist [.fold fill_body]

theorem fill_has_empty_spelling : denotes fill [] := by north_star
theorem fill_has_0 : denotes fill [d0] := by north_star

/-- The fill factor's exact membership, as a reusable factor lemma: `{{{},0}}`
wears the empty spelling and `0`, whatever the ambient amp. -/
theorem fill_ndenote (amp : Spelling → Prop) (p : Spelling) :
    ndenote fill amp p ↔ (p = [] ∨ p = [d0]) := by
  have hw : ∀ t, walk fill_body amp False t ↔ (t = [] ∨ t = [d0]) := by
    intro t
    simp only [fill_body, nlist, walk_cons, walk_single_fold, walk_single_face,
      walk_nil, unit_spells]
    tauto
  rw [ndenote_nonbinder _ _ _ (by decide)]
  simp only [fill, nlist, walk_cons, walk_single_fold, walk_nil, false_or]
  rw [fold_membership _ _ _ (by decide)]
  constructor
  · rintro (h | ⟨rfl, _⟩)
    · exact (hw p).mp h
    · exact Or.inl rfl
  · intro h
    exact Or.inl ((hw p).mpr h)

/- ---------------------------------------------------------------- -/
/- {{{},0}}{{{},0}}: Z^2 -- faces ``, 0, 00 and nothing longer. The  -/
/- doc's "two ways to spell 0 collide" is ownership, out of scope.   -/
/- ---------------------------------------------------------------- -/

def z2 : Node := nlist [.prod (.node fill (.node fill .nil))]

theorem z2_has_empty_spelling : denotes z2 [] := by north_star
theorem z2_has_0 : denotes z2 [d0] := by north_star
theorem z2_has_00 : denotes z2 [d0, d0] := by north_star

theorem z2_not_000 : ¬ denotes z2 [d0, d0, d0] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  rcases (fill_ndenote _ _).mp hp with rfl | rfl <;>
    rcases (fill_ndenote _ _).mp hp2 with rfl | rfl <;> simp_all

def fill_digits : Node :=
  nlist [.prod (.node fill (.node (nlist [.range d0 d9]) .nil))]

theorem fill_digits_has_5 : denotes fill_digits [d5] := by north_star
theorem fill_digits_has_05 : denotes fill_digits [d0, d5] := by north_star

theorem fill_digits_not_005 : ¬ denotes fill_digits [d0, d0, d5] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  rw [ndenote_nonbinder _ _ _ (by decide)] at hp2
  simp only [nlist, walk_cons, walk_single_range, walk_nil, false_or] at hp2
  rw [winb_range_singleton] at hp2
  obtain ⟨c, rfl, _, _⟩ := hp2
  rcases (fill_ndenote _ _).mp hp with rfl | rfl <;> simp_all

/- ---------------------------------------------------------------- -/
/- {{{},0}}{0,00}: cross-axis collision -- membership 0, 00, 000.    -/
/- The canonical-face drop and renumbering are ownership claims,     -/
/- out of scope with the rest of the order axis.                     -/
/- ---------------------------------------------------------------- -/

def z_cross : Node :=
  nlist [.prod (.node fill (.node (nlist [.face [d0], .face [d0, d0]]) .nil))]

theorem z_cross_has_0 : denotes z_cross [d0] := by north_star
theorem z_cross_has_00 : denotes z_cross [d0, d0] := by north_star
theorem z_cross_has_000 : denotes z_cross [d0, d0, d0] := by north_star

theorem z_cross_not_empty_spelling : ¬ denotes z_cross [] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  rcases two_face_ndenote hp2 with rfl | rfl <;> simp at hs

theorem z_cross_not_0000 : ¬ denotes z_cross [d0, d0, d0, d0] := by
  intro h
  obtain ⟨p, q, hs, hp, hp2⟩ := two_factor_split h
  rcases (fill_ndenote _ _).mp hp with rfl | rfl <;>
    rcases two_face_ndenote hp2 with rfl | rfl <;> simp_all

/- ---------------------------------------------------------------- -/
/- {a, &{b}}: closure -- a, ab, abb, ...; nothing else.             -/
/- ---------------------------------------------------------------- -/

def amp_b : Node :=
  nlist [.face [la], .prod (.amp (.node (nlist [.face [lb]]) .nil))]

theorem amp_b_has_a : denotes amp_b [la] := by north_star
theorem amp_b_has_ab : denotes amp_b [la, lb] := by north_star
theorem amp_b_has_abb : denotes amp_b [la, lb, lb] := by north_star

theorem amp_b_stage_headed : ∀ k s, stage amp_b k s → ∃ r, s = la :: r := by
  refine stage_invariant amp_b _ fun k ih s h => ?_
  simp only [amp_b, nlist, walk_cons, walk_single_prod, walk_single_face,
    walk_nil] at h
  rcases h with (h | h) | h
  · exact h.elim
  · exact ⟨[], h⟩
  · rw [fsplit_famp] at h
    obtain ⟨p, q, rfl, hp, hq⟩ := h
    simp only [fsplit_fnode, fsplit_fnil] at hq
    obtain ⟨p', q', rfl, _, rfl⟩ := hq
    obtain ⟨r, rfl⟩ := ih p hp
    exact ⟨r ++ p' ++ [], by simp⟩

theorem amp_b_not_b : ¬ denotes amp_b [lb] := by
  intro h
  rw [denotes, ndenote_binder _ _ _ (by decide)] at h
  obtain ⟨k, hk⟩ := h
  obtain ⟨r, hr⟩ := amp_b_stage_headed k [lb] hk
  simp at hr

/- ---------------------------------------------------------------- -/
/- {ab, {a}&{b}}: a^n b^n. aabb in; aab out (stages have even len). -/
/- ---------------------------------------------------------------- -/

def anbn : Node :=
  nlist [.face [la, lb],
    .prod (.node (nlist [.face [la]]) (.amp (.node (nlist [.face [lb]]) .nil)))]

theorem anbn_has_ab : denotes anbn [la, lb] := by north_star
theorem anbn_has_aabb : denotes anbn [la, la, lb, lb] := by north_star

/-- Appending one more copy is the same as prepending it: the snoc form of `replicate`. -/
theorem replicate_snoc (n : ℕ) (a : Code) :
    List.replicate n a ++ [a] = a :: List.replicate n a := by
  rw [← List.replicate_succ', List.replicate_succ]

/-- Every stage member is some `a^n b^n`, `1 ≤ n` -- the forward half of exactness, by stage
induction carrying the full witness (evenness of the length is the immediate corollary, since
`|a^n b^n| = 2n`). -/
theorem anbn_stage_exact : ∀ k s, stage anbn k s →
    ∃ n, 1 ≤ n ∧ s = List.replicate n la ++ List.replicate n lb := by
  refine stage_invariant anbn _ fun k ih s h => ?_
  simp only [anbn, nlist, walk_cons, walk_single_prod, walk_single_face,
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

theorem anbn_not_aab : ¬ denotes anbn [la, la, lb] := by
  rw [anbn_exact]
  rintro ⟨n, -, heq⟩
  have hlen := congrArg List.length heq
  simp [List.length_append, List.length_replicate] at hlen
  omega

/- ---------------------------------------------------------------- -/
/- {0, {1..9, &{0..9}}}: canonical numerals -- membership samples.  -/
/- ---------------------------------------------------------------- -/

def numerals_body : Node :=
  nlist [.range d1 d9, .prod (.amp (.node (nlist [.range d0 d9]) .nil))]

def numerals : Node := nlist [.face [d0], .fold numerals_body]

theorem numerals_has_0 : denotes numerals [d0] := by north_star
theorem numerals_has_1 : denotes numerals [d1] := by north_star
theorem numerals_has_10 : denotes numerals [d1, d0] := by north_star
theorem numerals_has_950 : denotes numerals [d9, d5, d0] := by north_star

/-- Every closure stage of the numeral body heads with a nonzero digit: the
seed is `{1..9}` and each pass only appends digits on the right. -/
theorem numerals_body_headed :
    ∀ k s, stage numerals_body k s → ∃ c r, s = c :: r ∧ d1 ≤ c ∧ c ≤ d9 := by
  refine stage_invariant numerals_body _ fun k ih s h => ?_
  simp only [numerals_body, nlist, walk_cons, walk_single_range,
    walk_single_prod, walk_nil, false_or] at h
  rcases h with h | h
  · rw [winb_range_singleton] at h
    obtain ⟨c, rfl, h1, h2⟩ := h
    exact ⟨c, [], rfl, h1, h2⟩
  · rw [fsplit_famp] at h
    obtain ⟨p, q, rfl, hp, hq⟩ := h
    rw [fsplit_fnode] at hq
    obtain ⟨p2, q2, rfl, hp2, hq2⟩ := hq
    rw [fsplit_fnil] at hq2
    subst hq2
    obtain ⟨c, r, rfl, h1, h2⟩ := ih p hp
    exact ⟨c, r ++ (p2 ++ []), by simp, h1, h2⟩

/-- The doc's "first-appearance order is value order" needs the order axis;
what membership can say is that a leading zero never appears. -/
theorem numerals_not_01 : ¬ denotes numerals [d0, d1] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [numerals, nlist, walk_cons, walk_single_face, walk_single_fold,
    walk_nil, false_or] at h
  rcases h with h | h
  · simp at h
  · rw [spells_fold_binder _ _ _ (by decide)] at h
    obtain ⟨k, hk⟩ := h
    obtain ⟨c, r, hcr, h1, _⟩ := numerals_body_headed k _ hk
    simp only [List.cons.injEq] at hcr
    obtain ⟨rfl, _⟩ := hcr
    exact absurd h1 (by decide)

/- ---------------------------------------------------------------- -/
/- {{{}}, &C}: final segment's demotion -- with `C = {a..z}`, the    -/
/- closure of the unit wears every spelling over the letters, the    -/
/- empty spelling included. The two-sided law is                     -/
/- `unitClosure_generates` in `Laws`; these are its samples.         -/
/- ---------------------------------------------------------------- -/

def all_letters : Node := unitClosure la lz

theorem all_letters_has_empty_spelling : denotes all_letters [] :=
  (unitClosure_generates la lz []).mpr (by simp)

theorem all_letters_has_a : denotes all_letters [la] :=
  (unitClosure_generates la lz [la]).mpr (by decide)

theorem all_letters_has_ba : denotes all_letters [lb, la] :=
  (unitClosure_generates la lz [lb, la]).mpr (by decide)

theorem all_letters_not_digit : ¬ denotes all_letters [d0] := by
  intro h
  have hd := (unitClosure_generates la lz [d0]).mp h d0 (by simp)
  exact absurd hd.2 (by decide)

/- ---------------------------------------------------------------- -/
/- {&} empty; {a, &} is {a}; {a.., !{&}} is {a..}: bare-`&` no-ops. -/
/- ---------------------------------------------------------------- -/

theorem bare_amp_row (s : Spelling) : ¬ denotes (nsingle .amp) s :=
  bare_amp_empty s

theorem self_union_row (s : Spelling) :
    denotes (.cons (.face [la]) (nsingle .amp)) s ↔ s = [la] :=
  self_union_noop [la] s

theorem negative_amp_row (s : Spelling) :
    denotes (.cons (.final [la]) (nsingle (.sub (nsingle .amp)))) s
      ↔ winb (finalWindow [la]) s = true :=
  negative_amp_noop [la] s

theorem negative_amp_row_has_f :
    denotes (.cons (.final [la]) (nsingle (.sub (nsingle .amp)))) [lf] := by
  rw [negative_amp_row]; decide

/- ---------------------------------------------------------------- -/
/- {a, {{{},0}}&}: unguarded fill -- membership samples.            -/
/- ---------------------------------------------------------------- -/

def unguarded_fill : Node :=
  nlist [.face [la], .prod (.node fill (.amp .nil))]

theorem unguarded_fill_has_a : denotes unguarded_fill [la] := by north_star
theorem unguarded_fill_has_0a : denotes unguarded_fill [d0, la] := by north_star
theorem unguarded_fill_has_00a : denotes unguarded_fill [d0, d0, la] := by north_star

/-- Every stage spelling of the unguarded fill ends in `a`: the fill factor
only ever prepends. -/
theorem unguarded_fill_stage_tailed :
    ∀ k s, stage unguarded_fill k s → ∃ r, s = r ++ [la] := by
  refine stage_invariant unguarded_fill _ fun k ih s h => ?_
  simp only [unguarded_fill, nlist, walk_cons, walk_single_face,
    walk_single_prod, walk_nil, false_or] at h
  rcases h with rfl | h
  · exact ⟨[], rfl⟩
  · rw [fsplit_fnode] at h
    obtain ⟨p, q, rfl, _, hq⟩ := h
    rw [fsplit_famp] at hq
    obtain ⟨p2, q2, rfl, hp2, hq2⟩ := hq
    rw [fsplit_fnil] at hq2
    subst hq2
    obtain ⟨r, rfl⟩ := ih p2 hp2
    exact ⟨p ++ r, by simp⟩

theorem unguarded_fill_not_0 : ¬ denotes unguarded_fill [d0] := by
  intro h
  rw [denotes, ndenote_binder _ _ _ (by decide)] at h
  obtain ⟨k, hk⟩ := h
  obtain ⟨r, hr⟩ := unguarded_fill_stage_tailed k [d0] hk
  rcases r with _ | ⟨x, r⟩ <;> simp_all

/- ---------------------------------------------------------------- -/
/- {ab, &&}: nonlinear closure -- ab, abab, ababab, ...             -/
/- ---------------------------------------------------------------- -/

def abab : Node := nlist [.face [la, lb], .prod (.amp (.amp .nil))]

theorem abab_has_ab : denotes abab [la, lb] := by north_star
theorem abab_has_abab : denotes abab [la, lb, la, lb] := by north_star

theorem abab_stage_even : ∀ k s, stage abab k s → s.length % 2 = 0 := by
  refine stage_invariant abab _ fun k ih s h => ?_
  simp only [abab, nlist, walk_cons, walk_single_face, walk_single_prod,
    walk_nil, false_or] at h
  rcases h with rfl | h
  · decide
  · rw [fsplit_famp] at h
    obtain ⟨p, q, rfl, hp, hq⟩ := h
    rw [fsplit_famp] at hq
    obtain ⟨p2, q2, rfl, hp2, hq2⟩ := hq
    rw [fsplit_fnil] at hq2
    subst hq2
    have h1 := ih p hp
    have h2 := ih p2 hp2
    simp only [List.length_append, List.length_nil]
    omega

theorem abab_not_aba : ¬ denotes abab [la, lb, la] := by
  intro h
  rw [denotes, ndenote_binder _ _ _ (by decide)] at h
  obtain ⟨k, hk⟩ := h
  have := abab_stage_even k _ hk
  simp at this

/- ---------------------------------------------------------------- -/
/- { {(}{b}{a..}{)}, {(}&&{)} }: binary trees -- membership samples. -/
/- The omega^omega order type is the order axis, out of scope.       -/
/- ---------------------------------------------------------------- -/

def btrees : Node :=
  nlist [.prod (.node (nlist [.face [lpar]])
           (.node (nlist [.face [lb]])
           (.node (nlist [.final [la]])
           (.node (nlist [.face [rpar]]) .nil)))),
         .prod (.node (nlist [.face [lpar]])
           (.amp (.amp (.node (nlist [.face [rpar]]) .nil))))]

theorem btrees_has_leaf : denotes btrees [lpar, lb, la, rpar] := by north_star
theorem btrees_has_pair :
    denotes btrees [lpar, lpar, lb, la, rpar, lpar, lb, lb, rpar, rpar] := by
  north_star

/-- Every stage spelling closes on `)`: both bodies end their products with
the literal `{)}` factor. -/
theorem btrees_stage_closed :
    ∀ k s, stage btrees k s → ∃ r, s = r ++ [rpar] := by
  refine stage_invariant btrees _ fun k ih s h => ?_
  simp only [btrees, nlist, walk_cons, walk_single_prod, walk_nil,
    false_or] at h
  rcases h with h | h <;>
    simp only [fsplit_fnode, fsplit_famp, fsplit_fnil] at h <;>
    obtain ⟨p1, q1, rfl, -, p2, q2, rfl, -, p3, q3, rfl, -, p4, q4, rfl, hp4, rfl⟩ := h <;>
    exact ⟨p1 ++ (p2 ++ p3), by simp [face_ndenote hp4]⟩

theorem btrees_not_lparen : ¬ denotes btrees [lpar] := by
  intro h
  rw [denotes, ndenote_binder _ _ _ (by decide)] at h
  obtain ⟨k, hk⟩ := h
  obtain ⟨r, hr⟩ := btrees_stage_closed k [lpar] hk
  rcases r with _ | ⟨x, r⟩ <;> simp_all

end L1
