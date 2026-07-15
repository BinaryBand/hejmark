/- L1 north-star table (`docs/foundation/L1_TEMP.md`), at the membership level.

Port of `static/formal/L1/NorthStar.v`. Positive rows compute through
`containsb_sound`: `sndNodeb` and `containsb` are both closed booleans, so
`native_decide` (compiled) settles them -- the Lean analogue of Coq's
`vm_compute`. Negative and emptiness rows are proved at the Prop level (the
evaluator is sound, not complete), mostly as corollaries of `Laws`.

Out of scope here, with the rest of the order axis: every claim about entry
order, values, collision ownership, and order types.

Toy code assignment: letters a..z are 0..25, digits 0..9 are 100..109. -/
import L1.Evaluator

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

/- ---------------------------------------------------------------- -/
/- {a,b,c}                                                          -/
/- ---------------------------------------------------------------- -/

def abc : Node := nlist [.face [la], .face [lb], .face [lc]]

theorem abc_has_b : denotes abc [lb] := by north_star

theorem abc_not_d : ¬ denotes abc [ld] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [abc, nlist, walk_cons, walk_single_face, walk, nsingle] at h
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
  simp only [a_to_z, nlist, walk_cons, walk_single_range, walk, nsingle] at h
  rcases h with h | h <;> simp_all [winb, shortlexLe, shortlexLt, lexLt, rangeWindow]

theorem a_to_z_not_aa : ¬ denotes a_to_z [la, la] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [a_to_z, nlist, walk_cons, walk_single_range, walk, nsingle] at h
  rcases h with h | h <;> simp_all [winb, shortlexLt, rangeWindow]

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
    · simp only [nlist, walk_cons, walk_single_face, walk, nsingle] at h
      rcases h with (h | h) | h <;> simp_all
    · exact (hempty cat) (by
        simp only [nlist, walk_cons, walk_single_face, walk, nsingle]
        left; right; rfl)

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
  rw [consonants, nlist, nlist, walk_cons, walk_cons, walk, walk_single_sub,
    walk_single_range] at h
  refine h.2 ?_
  simp only [nlist, walk_cons, walk_single_face, walk, nsingle]
  left; left; left; left; right; rfl

/- ---------------------------------------------------------------- -/
/- {{cat,feline}, !{feline}}: subtraction strips a face.            -/
/- ---------------------------------------------------------------- -/

def cat_only : Node :=
  nlist [.fold (nlist [.face cat, .face feline]), .sub (nlist [.face feline])]

theorem cat_only_has_cat : denotes cat_only cat := by north_star

theorem cat_only_not_feline : ¬ denotes cat_only feline := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  rw [cat_only, nlist, nlist, walk_cons, walk_cons, walk, walk_single_sub] at h
  refine h.2 ?_
  simp only [nlist, walk_cons, walk_single_face, walk, nsingle]
  right; rfl

/- ---------------------------------------------------------------- -/
/- {a..}: a final segment, unbounded above.                        -/
/- ---------------------------------------------------------------- -/

def a_final : Node := nlist [.final [la]]

theorem a_final_has_z : denotes a_final [lz] := by north_star
theorem a_final_has_aa : denotes a_final [la, la] := by north_star

theorem a_final_not_empty_spelling : ¬ denotes a_final [] := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [a_final, nlist, walk_cons, walk_single_final, walk, nsingle] at h
  rcases h with h | h <;> simp_all [winb, shortlexLe, shortlexLt, lexLt, finalWindow]

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
theorem prod_row_has_abc : denotes prod_row [la, lb, lc] := by north_star

def collision_row : Node :=
  nlist [.prod (.node (nlist [.face [la], .face [la, lb]])
    (.node (nlist [.face [lc], .face [lb, lc]]) .nil))]

theorem collision_row_has_abc : denotes collision_row [la, lb, lc] := by north_star

def final_times_b : Node :=
  nlist [.prod (.node (nlist [.final [la]]) (.node (nlist [.face [lb]]) .nil))]

theorem final_times_b_has_ab : denotes final_times_b [la, lb] := by north_star
theorem final_times_b_has_zb : denotes final_times_b [lz, lb] := by north_star

/- ---------------------------------------------------------------- -/
/- {a,!{a}}: the empty universe.                                    -/
/- ---------------------------------------------------------------- -/

def a_minus_a : Node := nlist [.face [la], .sub (nlist [.face [la]])]

theorem a_minus_a_empty (s : Spelling) : ¬ denotes a_minus_a s := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  rw [a_minus_a, nlist, nlist, walk_cons, walk_cons, walk, walk_single_sub,
    walk_single_face] at h
  obtain ⟨h1, h2⟩ := h
  refine h2 ?_
  simp only [nlist, walk_cons, walk_single_face, walk, nsingle]
  rcases h1 with h1 | h1
  · exact h1.elim
  · left; right; exact h1

/- ---------------------------------------------------------------- -/
/- {z..a}: a reversed range is empty.                              -/
/- ---------------------------------------------------------------- -/

def z_to_a : Node := nlist [.range lz la]

theorem z_to_a_empty (s : Spelling) : ¬ denotes z_to_a s := by
  intro h
  rw [denotes, ndenote_nonbinder _ _ _ (by decide)] at h
  simp only [z_to_a, nlist, walk_cons, walk_single_range, walk, nsingle] at h
  rcases h with h | h
  · exact h.elim
  · exact range_reversed_empty lz la (fun _ => False) s (by decide) h

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
/- {{{},0}}: the fill factor -- faces `` and `0`.                   -/
/- ---------------------------------------------------------------- -/

def fill_body : Node := nlist [.fold .nil, .face [d0]]
def fill : Node := nlist [.fold fill_body]

theorem fill_has_empty_spelling : denotes fill [] := by north_star
theorem fill_has_0 : denotes fill [d0] := by north_star

def fill_digits : Node :=
  nlist [.prod (.node fill (.node (nlist [.range d0 d9]) .nil))]

theorem fill_digits_has_5 : denotes fill_digits [d5] := by north_star
theorem fill_digits_has_05 : denotes fill_digits [d0, d5] := by north_star

/- ---------------------------------------------------------------- -/
/- {a, &{b}}: closure -- a, ab, abb, ...; nothing else.             -/
/- ---------------------------------------------------------------- -/

def amp_b : Node :=
  nlist [.face [la], .prod (.amp (.node (nlist [.face [lb]]) .nil))]

theorem amp_b_has_a : denotes amp_b [la] := by north_star
theorem amp_b_has_ab : denotes amp_b [la, lb] := by north_star
theorem amp_b_has_abb : denotes amp_b [la, lb, lb] := by north_star

theorem amp_b_stage_headed : ∀ k s, stage amp_b k s → ∃ r, s = la :: r := by
  intro k
  induction k with
  | zero => intro s h; rw [stage_zero] at h; exact h.elim
  | succ k ih =>
      intro s h
      rw [stage_succ] at h
      rcases h with h | h
      · exact ih s h
      · rw [amp_b, nlist, nlist, walk_cons, walk_cons, walk, walk_single_prod,
          walk_single_face] at h
        rcases h with (h | h) | h
        · exact h.elim
        · exact ⟨[], h⟩
        · rw [fsplit_famp] at h
          obtain ⟨p, q, rfl, hp, hq⟩ := h
          rw [fsplit_fnode, fsplit_fnil] at hq
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

theorem anbn_stage_even : ∀ k s, stage anbn k s → Nat.even s.length := by
  intro k
  induction k with
  | zero => intro s h; rw [stage_zero] at h; exact h.elim
  | succ k ih =>
      intro s h
      rw [stage_succ] at h
      rcases h with h | h
      · exact ih s h
      · rw [anbn, nlist, nlist, walk_cons, walk_cons, walk, walk_single_prod,
          walk_single_face] at h
        rcases h with (h | h) | h
        · exact h.elim
        · subst h; decide
        · rw [fsplit_fnode, fsplit_fnil] at h
          obtain ⟨p, q, rfl, hp, hq⟩ := h
          rw [ndenote_nonbinder _ _ _ (by decide), walk_single_face] at hp
          rcases hp with hp | rfl
          · exact hp.elim
          rw [fsplit_famp] at hq
          obtain ⟨p2, q2, rfl, hamp, hq2⟩ := hq
          rw [fsplit_fnode, fsplit_fnil] at hq2
          obtain ⟨p3, q3, rfl, hp3, rfl⟩ := hq2
          rw [ndenote_nonbinder _ _ _ (by decide), walk_single_face] at hp3
          rcases hp3 with hp3 | rfl
          · exact hp3.elim
          have := ih p2 hamp
          simp only [List.length_append, List.length_cons, List.length_nil] at this ⊢
          omega

theorem anbn_not_aab : ¬ denotes anbn [la, la, lb] := by
  intro h
  rw [denotes, ndenote_binder _ _ _ (by decide)] at h
  obtain ⟨k, hk⟩ := h
  have := anbn_stage_even k [la, la, lb] hk
  simp at this

/- ---------------------------------------------------------------- -/
/- {0, {1..9, &{0..9}}}: canonical numerals -- membership samples.  -/
/- ---------------------------------------------------------------- -/

def numerals : Node :=
  nlist [.face [d0],
    .fold (nlist [.range d1 d9, .prod (.amp (.node (nlist [.range d0 d9]) .nil))])]

theorem numerals_has_0 : denotes numerals [d0] := by north_star
theorem numerals_has_1 : denotes numerals [d1] := by north_star
theorem numerals_has_10 : denotes numerals [d1, d0] := by north_star
theorem numerals_has_950 : denotes numerals [d9, d5, d0] := by north_star

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

/- ---------------------------------------------------------------- -/
/- {ab, &&}: nonlinear closure -- ab, abab, ababab, ...             -/
/- ---------------------------------------------------------------- -/

def abab : Node := nlist [.face [la, lb], .prod (.amp (.amp .nil))]

theorem abab_has_ab : denotes abab [la, lb] := by north_star
theorem abab_has_abab : denotes abab [la, lb, la, lb] := by north_star

end L1
