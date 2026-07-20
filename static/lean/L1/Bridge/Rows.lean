/- L1 bridge: the transfinite rows -- entry types past omega on real syntax.

`docs/foundation/L1.md` (Bounded transfinitude): "union alone gives omega
plus a finite tail; product climbs -- `{b,c}{a..}` is omega*2,
`{b}{a..}{b}{a..}` is omega^2 ... In `{a..}{a..}` the least split pins the
prefix ... and the type collapses." This file computes those rows over the
real syntax, through `Product.lean`'s owner order and `Union.lean`'s
body-major order. The codes are fixed small numerals: the omega factor is
`unitClosure 0 1` (every spelling over `{0, 1}`), the front faces and the
seam marker are `2` and `3` -- outside the closure range, so the marker
pins each split.

- `collapseRow_prodLt_type` (`{a..}{a..}`-extreme, type omega): with the
  empty spelling in both factors every entry is claimed by the split
  `([], s)`, so the owner order is exactly the spelling order -- collision
  collapses the pre-collision omega*omega all the way to one omega. The
  doc's row keeps nonempty factors and collapses to omega*k; that graded
  form stays with the abstract `cofinite_collision_collapses`.
- `twoBlocks_prodLt_type` (`{b,c}{a..}`, type omega*2): the front faces
  sit outside the closure range, splits are unique, and the enumeration is
  the ordinal product -- two full omega-blocks.
- `seamRow_prodLt_type` (type omega^2): the doc's `{b}{a..}{b}{a..}`
  written two-factor, with the marker `2` closing the first block
  (`markedBlock`). The marker is outside the closure range so each
  spelling splits at its unique marker; the in-range-seam survivor story
  (seams collide, omega^2 still stands) stays with the abstract
  `seam_collision_survives`.
- `unionRow_unionLt_type` (type omega + 2): a braced closure with a
  two-face tail -- the union enumeration continues past the limit, the
  doc's "omega plus a finite tail" on real syntax.
- `neCollapseRow_prodLt_type` (`{a..}{a..}` with nonempty factors, type
  omega*2): the doc-literal cofinite collision row -- splits collide
  everywhere, the least split pins the prefix to one code, and exactly
  `k = 2` blocks survive (the alphabet size of the range `{0, 1}`), the
  real-syntax face of `cofinite_collision_collapses`. -/
import L1.Bridge.RecOrder

namespace L1

open Ordinal

/- ---------------------------------------------------------------- -/
/- Small helpers: singleton shortlex, marker surgery, the closure    -/
/- range.                                                            -/
/- ---------------------------------------------------------------- -/

theorem face_denotes_iff (t s : Spelling) :
    denotes (nsingle (.face t)) s ↔ s = t :=
  ndenote_face t _ s

/-- Cutting at a marker neither side contains is unambiguous -- the list
surgery behind every unique-split argument below. -/
theorem append_marker_inj {c : Code} {u v u' v' : Spelling}
    (hu : c ∉ u) (hu' : c ∉ u') (h : u ++ c :: v = u' ++ c :: v') :
    u = u' ∧ v = v' := by
  have aux : ∀ {a b a' b' : Spelling}, c ∉ a' → a ++ c :: b = a' ++ c :: b' →
      a.length < a'.length → False := by
    intro a b a' b' ha' hab hlt
    have hpre1 : a <+: a ++ c :: b := List.prefix_append a (c :: b)
    have hpre2 : a' <+: a' ++ c :: b' := List.prefix_append a' (c :: b')
    rw [hab] at hpre1
    obtain ⟨t, rfl⟩ := List.prefix_of_prefix_length_le hpre1 hpre2 (Nat.le_of_lt hlt)
    rw [List.append_assoc] at hab
    have htail : c :: b = t ++ c :: b' := List.append_cancel_left hab
    cases t with
    | nil => simp at hlt
    | cons th tt =>
        simp only [List.cons_append, List.cons.injEq] at htail
        exact ha' (List.mem_append_right a (htail.1 ▸ List.mem_cons_self))
  rcases Nat.lt_trichotomy u.length u'.length with hlt | heq | hgt
  · exact (aux hu' h hlt).elim
  · obtain ⟨h1, h2⟩ := List.append_inj h heq
    exact ⟨h1, ((List.cons.injEq _ _ _ _).mp h2).2⟩
  · exact (aux hu h.symm hgt).elim

/-- The omega factor's denotation, with the vacuous lower bound dropped. -/
theorem unitClosure01_denotes (s : Spelling) :
    denotes (unitClosure 0 1) s ↔ ∀ c ∈ s, c ≤ 1 := by
  rw [unitClosure_generates]
  exact ⟨fun h c hc => (h c hc).2, fun h c hc => ⟨Nat.zero_le c, h c hc⟩⟩

/- ---------------------------------------------------------------- -/
/- The collapse row: collision alone pulls omega*omega down to one   -/
/- omega.                                                            -/
/- ---------------------------------------------------------------- -/

/-- With the empty spelling in the first factor, every entry is owned by
the split `([], s)`: any nonempty prefix loses positionally to the empty
one. -/
theorem collapseRow_leastSplit
    (e : Entries (prod2 (unitClosure 0 1) (unitClosure 0 1))) :
    leastSplit (unitClosure 0 1) (unitClosure 0 1) e = ([], e.1) := by
  have hcodes : ∀ c ∈ e.1, c ≤ 1 := by
    obtain ⟨p, q, heq, hp, hq⟩ := (prod2_denotes_iff _ _ _).mp e.2
    intro c hc
    rw [heq] at hc
    rcases List.mem_append.mp hc with h | h
    · exact (unitClosure01_denotes p).mp hp c h
    · exact (unitClosure01_denotes q).mp hq c h
  refine leastSplit_eq _ _ e
    ⟨(List.nil_append e.1).symm, (unitClosure01_denotes []).mpr (by simp),
      (unitClosure01_denotes e.1).mpr hcodes⟩ ?_
  rintro ⟨p, q⟩ ⟨heq, -, -⟩
  cases p with
  | nil =>
      left
      simp only [List.nil_append] at heq
      rw [heq]
  | cons c rest =>
      right
      exact Prod.lex_def.mpr (Or.inl (List.Shortlex.of_length_lt (by simp)))

/-- On the collapse row the owner order is the spelling order: collision
ownership erases the product structure entirely. -/
theorem collapseRow_prodLt_iff
    (x y : Entries (prod2 (unitClosure 0 1) (unitClosure 0 1))) :
    prodLt (unitClosure 0 1) (unitClosure 0 1) x y
      ↔ List.Shortlex ((· < ·) : Code → Code → Prop) x.1 y.1 := by
  show splitLt (leastSplit _ _ x) (leastSplit _ _ y) ↔ _
  rw [collapseRow_leastSplit x, collapseRow_leastSplit y]
  show Prod.Lex _ _ ([], x.1) ([], y.1) ↔ _
  rw [Prod.lex_def]
  constructor
  · rintro (h | ⟨-, h⟩)
    · exact absurd h
        (irrefl_of (List.Shortlex ((· < ·) : Code → Code → Prop)) _)
    · exact h
  · intro h
    exact Or.inr ⟨rfl, h⟩

/-- Headline: real-syntax collision collapse. The pre-collision address
space of the double closure is omega*omega, but the least-split rule hands
every spelling to `([], s)` and the surviving enumeration is one omega --
the doc's "the least split pins the prefix ... and the type collapses",
in the extreme form the empty spelling forces. -/
theorem collapseRow_prodLt_type :
    Ordinal.type (prodLt (unitClosure 0 1) (unitClosure 0 1)) = ω := by
  have hiso : prodLt (unitClosure 0 1) (unitClosure 0 1)
      ≃r entrySpellLt (prod2 (unitClosure 0 1) (unitClosure 0 1)) :=
    ⟨Equiv.refl _, by
      intro x y
      exact (collapseRow_prodLt_iff x y).symm⟩
  rw [Ordinal.type_eq.mpr ⟨hiso⟩]
  refine entriesType_eq_omega0 _ 1 ?_ ?_
  · intro s hs c hc
    obtain ⟨p, q, rfl, hp, hq⟩ := (prod2_denotes_iff _ _ s).mp hs
    rcases List.mem_append.mp hc with h | h
    · exact (unitClosure01_denotes p).mp hp c h
    · exact (unitClosure01_denotes q).mp hq c h
  · refine Set.infinite_of_injective_forall_mem
      (f := fun n : ℕ => List.replicate n 0) ?_ ?_
    · intro a b hab
      simpa using congrArg List.length hab
    · intro n
      rw [Set.mem_setOf_eq, prod2_denotes_iff]
      refine ⟨List.replicate n 0, [], (List.append_nil _).symm, ?_, ?_⟩
      · exact (unitClosure01_denotes _).mpr
          (fun c hc => by rw [List.eq_of_mem_replicate hc]; omega)
      · exact (unitClosure01_denotes []).mpr (by simp)

/- ---------------------------------------------------------------- -/
/- The two-blocks row {b,c}{a..}: omega * 2.                         -/
/- ---------------------------------------------------------------- -/

/-- The two-face front factor `{b,c}`: codes `2` and `3`, outside the
closure range. -/
def twoFaces : Node := .cons (.face [2]) (nsingle (.face [3]))

theorem twoFaces_bindsb : bindsb twoFaces = false := rfl

theorem twoFaces_subfreeb : subfreeb twoFaces = true := rfl

theorem twoFaces_denotes_iff (s : Spelling) :
    denotes twoFaces s ↔ s = [2] ∨ s = [3] := by
  show ndenote twoFaces (fun _ => False) s ↔ _
  rw [ndenote_nonbinder _ _ _ twoFaces_bindsb]
  show walk (.cons (.face [2]) (nsingle (.face [3]))) _ False s ↔ _
  rw [walk_cons, walk_single_face, walk_single_face]
  tauto

/-- The front factor wears exactly two entries, in spelling order. -/
noncomputable def twoFacesIso :
    entrySpellLt twoFaces ≃r ((· < ·) : Fin 2 → Fin 2 → Prop) where
  toEquiv := Equiv.ofBijective
    (fun e => if e.1 = [2] then (0 : Fin 2) else 1) (by
    constructor
    · rintro ⟨s, hs⟩ ⟨t, ht⟩ hst
      rcases (twoFaces_denotes_iff s).mp hs with rfl | rfl <;>
        rcases (twoFaces_denotes_iff t).mp ht with rfl | rfl <;>
        simp_all
    · intro i
      fin_cases i
      · exact ⟨⟨[2], (twoFaces_denotes_iff [2]).mpr (Or.inl rfl)⟩, by simp⟩
      · exact ⟨⟨[3], (twoFaces_denotes_iff [3]).mpr (Or.inr rfl)⟩, by simp⟩)
  map_rel_iff' := by
    rintro ⟨s, hs⟩ ⟨t, ht⟩
    rcases (twoFaces_denotes_iff s).mp hs with rfl | rfl <;>
      rcases (twoFaces_denotes_iff t).mp ht with rfl | rfl <;>
      simp [entrySpellLt, subrel_val]

theorem twoFaces_entriesType : entriesType twoFaces = 2 := by
  show Ordinal.type (entrySpellLt twoFaces) = 2
  rw [Ordinal.type_eq.mpr ⟨twoFacesIso⟩,
    show Ordinal.type ((· < ·) : Fin 2 → Fin 2 → Prop) = ((2 : ℕ) : Ordinal)
      from type_fin 2]
  norm_num

/-- The front faces sit outside the closure range, so the first code pins
the block: splits are unique. -/
theorem twoBlocks_splits_unique {s : Spelling} {pq pq' : Spelling × Spelling}
    (h : IsSplit twoFaces (unitClosure 0 1) s pq)
    (h' : IsSplit twoFaces (unitClosure 0 1) s pq') : pq = pq' := by
  obtain ⟨heq, hp, -⟩ := h
  obtain ⟨heq', hp', -⟩ := h'
  have hl : pq.1.length = 1 := by
    rcases (twoFaces_denotes_iff pq.1).mp hp with h2 | h2 <;> rw [h2] <;> rfl
  have hl' : pq'.1.length = 1 := by
    rcases (twoFaces_denotes_iff pq'.1).mp hp' with h2 | h2 <;> rw [h2] <;> rfl
  obtain ⟨h1, h2⟩ := List.append_inj (heq.symm.trans heq') (by omega)
  exact Prod.ext h1 h2

/-- Headline: the doc's north-star row `{b,c}{a..}` at omega*2, on real
syntax -- a finite front factor over an omega block is exactly two full
blocks, most significant digit on the left. -/
theorem twoBlocks_prodLt_type :
    Ordinal.type (prodLt twoFaces (unitClosure 0 1)) = ω * 2 := by
  rw [prodLt_type_of_unique_splits twoFaces (unitClosure 0 1)
      (fun _ _ _ h h' => twoBlocks_splits_unique h h'),
    unitClosure_entriesType 0 1 (by omega), twoFaces_entriesType]

/- ---------------------------------------------------------------- -/
/- The seam row at omega^2, marker outside the range.                -/
/- ---------------------------------------------------------------- -/

/-- The marked omega block: bounded strings closed by the marker `2` --
the doc's `{b}{a..}` block with the seam character written at the end. -/
def markedBlock : Node := prod2 (unitClosure 0 1) (nsingle (.face [2]))

theorem markedBlock_denotes_iff (s : Spelling) :
    denotes markedBlock s ↔ ∃ u, s = u ++ [2] ∧ ∀ c ∈ u, c ≤ 1 := by
  show denotes (prod2 (unitClosure 0 1) (nsingle (.face [2]))) s ↔ _
  rw [prod2_denotes_iff]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    rw [face_denotes_iff] at hq
    subst hq
    exact ⟨p, rfl, (unitClosure01_denotes p).mp hp⟩
  · rintro ⟨u, rfl, hu⟩
    exact ⟨u, [2], rfl, (unitClosure01_denotes u).mpr hu,
      (face_denotes_iff _ _).mpr rfl⟩

theorem markedBlock_entriesType : entriesType markedBlock = ω := by
  refine entriesType_eq_omega0 _ 2 ?_ ?_
  · intro s hs c hc
    obtain ⟨u, rfl, hu⟩ := (markedBlock_denotes_iff _).mp hs
    rcases List.mem_append.mp hc with h | h
    · have := hu c h; omega
    · have : c = 2 := List.mem_singleton.mp h
      omega
  · refine Set.infinite_of_injective_forall_mem
      (f := fun n : ℕ => List.replicate n 0 ++ [2]) ?_ ?_
    · intro a b hab
      have := congrArg List.length hab
      simpa using this
    · intro n
      rw [Set.mem_setOf_eq, markedBlock_denotes_iff]
      exact ⟨List.replicate n 0, rfl,
        fun c hc => by rw [List.eq_of_mem_replicate hc]; omega⟩

/-- The marker never appears inside a bounded segment, so every spelling
splits at its unique marker. -/
theorem seamRow_splits_unique {s : Spelling} {pq pq' : Spelling × Spelling}
    (h : IsSplit markedBlock (unitClosure 0 1) s pq)
    (h' : IsSplit markedBlock (unitClosure 0 1) s pq') : pq = pq' := by
  obtain ⟨heq, hp, -⟩ := h
  obtain ⟨heq', hp', -⟩ := h'
  obtain ⟨u, hu_eq, hu⟩ := (markedBlock_denotes_iff pq.1).mp hp
  obtain ⟨u', hu'_eq, hu'⟩ := (markedBlock_denotes_iff pq'.1).mp hp'
  have hh : u ++ 2 :: pq.2 = u' ++ 2 :: pq'.2 := by
    have hs := heq.symm.trans heq'
    rw [hu_eq, hu'_eq] at hs
    simpa [List.append_assoc] using hs
  have hnu : (2 : Code) ∉ u := fun hmem => by have := hu 2 hmem; omega
  have hnu' : (2 : Code) ∉ u' := fun hmem => by have := hu' 2 hmem; omega
  obtain ⟨h1, h2⟩ := append_marker_inj hnu hnu' hh
  refine Prod.ext ?_ h2
  rw [hu_eq, hu'_eq, h1]

/-- Headline: a transfinite product row at omega^2 on real syntax -- the
doc's `{b}{a..}{b}{a..}` written two-factor with the marker closing the
first block. Splits are pinned by the marker; the in-range-seam collision
story stays with the abstract `seam_collision_survives`. -/
theorem seamRow_prodLt_type :
    Ordinal.type (prodLt markedBlock (unitClosure 0 1)) = ω ^ (2 : Ordinal) := by
  rw [prodLt_type_of_unique_splits markedBlock (unitClosure 0 1)
      (fun _ _ _ h h' => seamRow_splits_unique h h'),
    unitClosure_entriesType 0 1 (by omega), markedBlock_entriesType,
    show (2 : Ordinal) = 1 + 1 by norm_num, opow_add, opow_one]

/- ---------------------------------------------------------------- -/
/- The union row: past the limit by a finite tail.                   -/
/- ---------------------------------------------------------------- -/

/-- Headline: the union enumeration continues past the limit -- a braced
closure with a two-face tail sits at omega + 2, the doc's "union alone
gives omega plus a finite tail" on real syntax. The closure enters braced
(`braced_denotes_iff`), the tail is disjoint (its codes sit outside the
closure range), and `unionLt_type_disjoint` reads off the ordinal sum. -/
theorem unionRow_unionLt_type :
    Ordinal.type (unionLt (braced (unitClosure 0 1)) twoFaces) = ω + 2 := by
  have hdisj : ∀ s, denotes (braced (unitClosure 0 1)) s → ¬ denotes twoFaces s := by
    intro s h1 h2
    rw [braced_denotes_iff _ (unitClosure_bindsb 0 1)] at h1
    have hcodes := (unitClosure01_denotes s).mp h1
    rcases (twoFaces_denotes_iff s).mp h2 with rfl | rfl
    · have := hcodes 2 (by simp); omega
    · have := hcodes 3 (by simp); omega
  have hbr : entriesType (braced (unitClosure 0 1)) = ω := by
    rw [entriesType_congr (braced_denotes_iff _ (unitClosure_bindsb 0 1))]
    exact unitClosure_entriesType 0 1 (by omega)
  rw [unionLt_type_disjoint _ _ (braced_bindsb _) twoFaces_bindsb
      twoFaces_subfreeb hdisj, hbr, twoFaces_entriesType]

/- ---------------------------------------------------------------- -/
/- The nonempty-factor collapse row {a..}{a..}: splits collide       -/
/- everywhere, omega * k survives with k the alphabet size.          -/
/- ---------------------------------------------------------------- -/

/-- The two-code range `{0..1}`: the singleton spellings of the closure
alphabet. -/
def rangeNode : Node := nsingle (.range 0 1)

theorem rangeNode_bindsb : bindsb rangeNode = false := rfl

theorem range01_denotes_iff (s : Spelling) :
    denotes rangeNode s ↔ s = [0] ∨ s = [1] := by
  show ndenote rangeNode (fun _ => False) s ↔ _
  rw [ndenote_nonbinder _ _ _ rangeNode_bindsb]
  show walk (nsingle (.range 0 1)) _ False s ↔ _
  rw [walk_single_range, false_or, winb_range_singleton]
  constructor
  · rintro ⟨c, rfl, -, hc⟩
    interval_cases c
    · exact Or.inl rfl
    · exact Or.inr rfl
  · rintro (rfl | rfl)
    · exact ⟨0, rfl, by omega, by omega⟩
    · exact ⟨1, rfl, by omega, by omega⟩

/-- The range factor wears exactly two entries, in spelling order. -/
noncomputable def rangeIso :
    entrySpellLt rangeNode ≃r ((· < ·) : Fin 2 → Fin 2 → Prop) where
  toEquiv := Equiv.ofBijective
    (fun e => if e.1 = [0] then (0 : Fin 2) else 1) (by
    constructor
    · rintro ⟨s, hs⟩ ⟨t, ht⟩ hst
      rcases (range01_denotes_iff s).mp hs with rfl | rfl <;>
        rcases (range01_denotes_iff t).mp ht with rfl | rfl <;>
        simp_all
    · intro i
      fin_cases i
      · exact ⟨⟨[0], (range01_denotes_iff [0]).mpr (Or.inl rfl)⟩, by simp⟩
      · exact ⟨⟨[1], (range01_denotes_iff [1]).mpr (Or.inr rfl)⟩, by simp⟩)
  map_rel_iff' := by
    rintro ⟨s, hs⟩ ⟨t, ht⟩
    rcases (range01_denotes_iff s).mp hs with rfl | rfl <;>
      rcases (range01_denotes_iff t).mp ht with rfl | rfl <;>
      simp [entrySpellLt, subrel_val]

theorem rangeNode_entriesType : entriesType rangeNode = 2 := by
  show Ordinal.type (entrySpellLt rangeNode) = 2
  rw [Ordinal.type_eq.mpr ⟨rangeIso⟩,
    show Ordinal.type ((· < ·) : Fin 2 → Fin 2 → Prop) = ((2 : ℕ) : Ordinal)
      from type_fin 2]
  norm_num

/-- The nonempty bounded strings: one range code, then any bounded string
-- the `{a..}` factor of the doc's collapse row, over the alphabet
`{0, 1}`. -/
def neBounded : Node := prod2 rangeNode (unitClosure 0 1)

theorem neBounded_denotes_iff (s : Spelling) :
    denotes neBounded s ↔ s ≠ [] ∧ ∀ c ∈ s, c ≤ 1 := by
  show denotes (prod2 rangeNode (unitClosure 0 1)) s ↔ _
  rw [prod2_denotes_iff]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    have hp01 := (range01_denotes_iff p).mp hp
    have hq1 := (unitClosure01_denotes q).mp hq
    constructor
    · rcases hp01 with rfl | rfl <;> simp
    · intro c hc
      rcases List.mem_append.mp hc with h | h
      · rcases hp01 with rfl | rfl <;>
          · have := List.mem_singleton.mp h; omega
      · exact hq1 c h
  · rintro ⟨hne, hcodes⟩
    obtain ⟨c, rest, rfl⟩ : ∃ c rest, s = c :: rest := by
      cases s with
      | nil => exact absurd rfl hne
      | cons c rest => exact ⟨c, rest, rfl⟩
    have hc1 : c ≤ 1 := hcodes c (by simp)
    refine ⟨[c], rest, rfl, ?_, ?_⟩
    · rw [range01_denotes_iff]
      interval_cases c
      · exact Or.inl rfl
      · exact Or.inr rfl
    · exact (unitClosure01_denotes rest).mpr
        (fun d hd => hcodes d (by simp [hd]))

theorem neBounded_entriesType : entriesType neBounded = ω := by
  refine entriesType_eq_omega0 _ 1 ?_ ?_
  · intro s hs c hc
    exact ((neBounded_denotes_iff s).mp hs).2 c hc
  · refine Set.infinite_of_injective_forall_mem
      (f := fun n : ℕ => List.replicate (n + 1) 0) ?_ ?_
    · intro a b hab
      have := congrArg List.length hab
      simpa using this
    · intro n
      rw [Set.mem_setOf_eq, neBounded_denotes_iff]
      exact ⟨by simp, fun c hc => by rw [List.eq_of_mem_replicate hc]; omega⟩

theorem neCollapse_len (e : Entries (prod2 neBounded neBounded)) :
    2 ≤ e.1.length := by
  obtain ⟨p, q, heq, hp, hq⟩ := (prod2_denotes_iff _ _ _).mp e.2
  have hp1 := List.length_pos_of_ne_nil ((neBounded_denotes_iff p).mp hp).1
  have hq1 := List.length_pos_of_ne_nil ((neBounded_denotes_iff q).mp hq).1
  rw [heq]
  simp only [List.length_append]
  omega

theorem neCollapse_codes (e : Entries (prod2 neBounded neBounded)) :
    ∀ d ∈ e.1, d ≤ 1 := by
  obtain ⟨p, q, heq, hp, hq⟩ := (prod2_denotes_iff _ _ _).mp e.2
  intro d hd
  rw [heq] at hd
  rcases List.mem_append.mp hd with h | h
  · exact ((neBounded_denotes_iff p).mp hp).2 d h
  · exact ((neBounded_denotes_iff q).mp hq).2 d h

/-- The collision resolution: with nonempty factors the least split pins
the prefix to exactly one code -- the doc's "the least split pins the
prefix", `splitSurvives_iff`'s content on real syntax. -/
theorem neCollapse_leastSplit (c : Code) (t : Spelling)
    (e : Entries (prod2 neBounded neBounded)) (heq : e.1 = c :: t) :
    leastSplit neBounded neBounded e = ([c], t) := by
  have hc : c ≤ 1 := neCollapse_codes e c (by rw [heq]; exact List.mem_cons_self)
  have ht : t ≠ [] := by
    have hlen := neCollapse_len e
    rw [heq] at hlen
    simp only [List.length_cons] at hlen
    intro h
    subst h
    simp at hlen
  refine leastSplit_eq _ _ e
    ⟨by rw [heq]; rfl,
      (neBounded_denotes_iff [c]).mpr ⟨by simp,
        fun d hd => by rw [List.mem_singleton.mp hd]; exact hc⟩,
      (neBounded_denotes_iff t).mpr ⟨ht,
        fun d hd => neCollapse_codes e d (by rw [heq]; exact List.mem_cons_of_mem c hd)⟩⟩
    ?_
  rintro ⟨p, q⟩ ⟨hpq, hp, -⟩
  have hpne := ((neBounded_denotes_iff p).mp hp).1
  obtain ⟨c', rest, rfl⟩ : ∃ c' rest, p = c' :: rest := by
    cases p with
    | nil => exact absurd rfl hpne
    | cons c' rest => exact ⟨c', rest, rfl⟩
  cases rest with
  | nil =>
      left
      have h2 : c :: t = c' :: q := heq.symm.trans hpq
      obtain ⟨rfl, rfl⟩ := (List.cons.injEq _ _ _ _).mp h2
      rfl
  | cons d rest' =>
      right
      exact Prod.lex_def.mpr (Or.inl (List.Shortlex.of_length_lt
        (by simp only [List.length_cons, List.length_nil]; omega)))

theorem neCollapse_split (e : Entries (prod2 neBounded neBounded)) :
    ∃ c t, e.1 = c :: t ∧ c ≤ 1 ∧ leastSplit neBounded neBounded e = ([c], t) := by
  obtain ⟨c, t, heq⟩ : ∃ c t, e.1 = c :: t := by
    have hlen := neCollapse_len e
    cases h : e.1 with
    | nil => rw [h] at hlen; simp at hlen
    | cons c t => exact ⟨c, t, rfl⟩
  exact ⟨c, t, heq, neCollapse_codes e c (by rw [heq]; exact List.mem_cons_self),
    neCollapse_leastSplit c t e heq⟩

theorem neCollapse_fst (e : Entries (prod2 neBounded neBounded)) :
    denotes rangeNode (leastSplit neBounded neBounded e).1 := by
  obtain ⟨c, t, -, hc, hls⟩ := neCollapse_split e
  rw [hls, range01_denotes_iff]
  interval_cases c
  · exact Or.inl rfl
  · exact Or.inr rfl

theorem neCollapse_snd (e : Entries (prod2 neBounded neBounded)) :
    denotes neBounded (leastSplit neBounded neBounded e).2 :=
  (leastSplit_isSplit neBounded neBounded e).2.2

/-- The survivors are exactly `(range code, nonempty bounded string)`
pairs, positionally ordered -- one full block per code point. -/
noncomputable def neCollapseIso :
    prodLt neBounded neBounded
      ≃r Prod.Lex (entrySpellLt rangeNode) (entrySpellLt neBounded) where
  toEquiv := Equiv.ofBijective (fun e =>
    (⟨(leastSplit neBounded neBounded e).1, neCollapse_fst e⟩,
     ⟨(leastSplit neBounded neBounded e).2, neCollapse_snd e⟩)) (by
    constructor
    · intro x y hxy
      simp only [Prod.mk.injEq, Subtype.mk.injEq] at hxy
      apply Subtype.ext
      rw [(leastSplit_isSplit _ _ x).1, (leastSplit_isSplit _ _ y).1,
        hxy.1, hxy.2]
    · rintro ⟨⟨p, hp⟩, ⟨q, hq⟩⟩
      have hp' : ∃ c, p = [c] ∧ c ≤ 1 := by
        rcases (range01_denotes_iff p).mp hp with rfl | rfl
        · exact ⟨0, rfl, by omega⟩
        · exact ⟨1, rfl, by omega⟩
      obtain ⟨c, rfl, hc⟩ := hp'
      have hcq : denotes (prod2 neBounded neBounded) ([c] ++ q) :=
        (prod2_denotes_iff _ _ _).mpr ⟨[c], q, rfl,
          (neBounded_denotes_iff [c]).mpr ⟨by simp,
            fun d hd => by rw [List.mem_singleton.mp hd]; exact hc⟩, hq⟩
      have hls : leastSplit neBounded neBounded ⟨[c] ++ q, hcq⟩ = ([c], q) :=
        neCollapse_leastSplit c q ⟨[c] ++ q, hcq⟩ rfl
      exact ⟨⟨[c] ++ q, hcq⟩, Prod.ext (Subtype.ext (congrArg Prod.fst hls))
        (Subtype.ext (congrArg Prod.snd hls))⟩)
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply, prodLt, entrySpellLt, Prod.lex_def,
      subrel_val, Subtype.mk.injEq]

/- ---------------------------------------------------------------- -/
/- 5e helpers: building-block enumerations under the recursive       -/
/- order.                                                            -/
/- ---------------------------------------------------------------- -/

/-- A face wears exactly one entry. -/
theorem faceEntriesType (t : Spelling) : entriesType (nsingle (.face t)) = 1 := by
  rw [entriesType, Ordinal.type_eq_one_iff_unique]
  exact ⟨⟨⟨⟨t, (face_denotes_iff t t).mpr rfl⟩⟩,
    fun e => Subtype.ext ((face_denotes_iff t e.1).mp e.2)⟩⟩

/-- A face keeps its one entry under the recursive order. -/
theorem face_entryRecType (t : Spelling) : entryRecType (nsingle (.face t)) = 1 :=
  (entryRecType_face t).trans (faceEntriesType t)

theorem twoFaces_eq_napp :
    twoFaces = napp (nsingle (.face [2])) (nsingle (.face [3])) := rfl

theorem twoFaces_nSubfree : nSubfree twoFaces = true := rfl

/-- The two-face front factor keeps its two entries under the recursive
order: disjoint faces, one entry each. -/
theorem twoFaces_entryRecType : entryRecType twoFaces = 2 := by
  have hdisj : ∀ s, denotes (nsingle (.face ([2] : Spelling))) s
      → ¬ denotes (nsingle (.face ([3] : Spelling))) s := by
    intro s h2 h3
    rw [face_denotes_iff] at h2 h3
    rw [h2] at h3
    simp at h3
  rw [twoFaces_eq_napp,
    entryRecType_napp_disjoint (nsingle (.face [2])) (nsingle (.face [3]))
      rfl rfl rfl rfl hdisj,
    face_entryRecType, face_entryRecType]
  exact one_add_one_eq_two

/-- The marker tail pins the marked block's splits: both tails are the marker
itself, so the cut point is forced. -/
theorem markedBlock_splits_unique {s : Spelling} {pq pq' : Spelling × Spelling}
    (h : IsSplit (unitClosure 0 1) (nsingle (.face [2])) s pq)
    (h' : IsSplit (unitClosure 0 1) (nsingle (.face [2])) s pq') : pq = pq' := by
  obtain ⟨heq, -, hq⟩ := h
  obtain ⟨heq', -, hq'⟩ := h'
  rw [face_denotes_iff] at hq hq'
  obtain ⟨h1, h2⟩ := List.append_inj' (heq.symm.trans heq') (by rw [hq, hq'])
  exact Prod.ext h1 h2

theorem markedBlock_nSubfree : nSubfree markedBlock = true := by
  simp [markedBlock, prod2, nsingle, nSubfree, mSubfree, fSubfree,
    unitClosure_nSubfree]

/-- The marked block under the recursive order: a full omega of bounded
prefixes, one marker entry each. -/
theorem markedBlock_entryRecType : entryRecType markedBlock = ω := by
  show entryRecType (prod2 (unitClosure 0 1) (nsingle (.face [2]))) = ω
  rw [entryRecType_prod2 (unitClosure 0 1) (nsingle (.face [2]))
      (unitClosure_nSubfree 0 1) rfl
      (fun _ _ _ h h' => markedBlock_splits_unique h h'),
    face_entryRecType, unitClosure_entryRecType 0 1 (by omega), one_mul]

/-- The range factor keeps its two entries under the recursive order. -/
theorem rangeNode_entryRecType : entryRecType rangeNode = 2 :=
  (entryRecType_range 0 1).trans rangeNode_entriesType

/-- The range head pins the nonempty-bounded splits: both heads are
singletons, so the cut point is forced. -/
theorem neBounded_splits_unique {s : Spelling} {pq pq' : Spelling × Spelling}
    (h : IsSplit rangeNode (unitClosure 0 1) s pq)
    (h' : IsSplit rangeNode (unitClosure 0 1) s pq') : pq = pq' := by
  obtain ⟨heq, hp, -⟩ := h
  obtain ⟨heq', hp', -⟩ := h'
  have hl : pq.1.length = pq'.1.length := by
    rcases (range01_denotes_iff pq.1).mp hp with h2 | h2 <;>
      rcases (range01_denotes_iff pq'.1).mp hp' with h3 | h3 <;>
      simp [h2, h3]
  obtain ⟨h1, h2⟩ := List.append_inj (heq.symm.trans heq') hl
  exact Prod.ext h1 h2

theorem neBounded_nSubfree : nSubfree neBounded = true := by
  simp [neBounded, rangeNode, prod2, nsingle, nSubfree, mSubfree, fSubfree,
    unitClosure_nSubfree]

/-- The nonempty bounded strings under the recursive order sit at omega*2,
not omega: unique splits make the recursive type positional --
`entryRecType (unitClosure 0 1) * entryRecType rangeNode` -- where the
spelling-order approximation interleaved the two lead blocks into one
omega. -/
theorem neBounded_entryRecType : entryRecType neBounded = ω * 2 := by
  show entryRecType (prod2 rangeNode (unitClosure 0 1)) = ω * 2
  rw [entryRecType_prod2 rangeNode (unitClosure 0 1) rfl (unitClosure_nSubfree 0 1)
      (fun _ _ _ h h' => neBounded_splits_unique h h'),
    rangeNode_entryRecType, unitClosure_entryRecType 0 1 (by omega)]

/-- The recursion's split choice on a singleton entry of `neBounded`: the
head is the singleton itself, the tail is empty -- pinned by unique
splits. -/
theorem neBounded_singleton_pieces (c : Code) (h : denotes neBounded [c])
    (hp : denotes rangeNode [c]) (hq : denotes (unitClosure 0 1) []) :
    prod2RecPieces rangeNode (unitClosure 0 1) ⟨[c], h⟩ = (⟨[c], hp⟩, ⟨[], hq⟩) := by
  have hpin : someSplit rangeNode (prodNode (.node (unitClosure 0 1) .nil)) [c]
      = ([c], []) :=
    prod2_someSplit_eq rangeNode (unitClosure 0 1)
      (fun _ _ _ h1 h2 => neBounded_splits_unique h1 h2)
      (List.append_nil [c]).symm hp hq
  exact Prod.ext (Subtype.ext (congrArg Prod.fst hpin))
    (Subtype.ext (congrArg Prod.snd hpin))

/-- The singleton entries of `neBounded` rank in code order -- the Shortlex
comparison on the range head lifted through the product comparison law. -/
theorem neBounded_headRank_lt (h0 : denotes neBounded [0])
    (h1 : denotes neBounded [1]) :
    entryRank neBounded ⟨[0], h0⟩ < entryRank neBounded ⟨[1], h1⟩ := by
  have hr0 : denotes rangeNode [0] := (range01_denotes_iff [0]).mpr (Or.inl rfl)
  have hr1 : denotes rangeNode [1] := (range01_denotes_iff [1]).mpr (Or.inr rfl)
  have hqe : denotes (unitClosure 0 1) [] := (unitClosure01_denotes []).mpr (by simp)
  have hsl : List.Shortlex ((· < ·) : Code → Code → Prop) [0] [1] :=
    (shortlexLt_iff_fshortlex [0] [1]).mp ((singleton_shortlexLt_iff 0 1).mpr (by omega))
  have hrlt : entryRank rangeNode ⟨[0], hr0⟩ < entryRank rangeNode ⟨[1], hr1⟩ :=
    (iff_of_eq (congrFun (congrFun (entryRecLt_range 0 1)
        (⟨[0], hr0⟩ : Entries (nsingle (.range 0 1)))) ⟨[1], hr1⟩)).mpr
      (show entrySpellLt (nsingle (.range 0 1)) ⟨[0], hr0⟩ ⟨[1], hr1⟩ from hsl)
  show entryRecLt (prod2 rangeNode (unitClosure 0 1)) ⟨[0], h0⟩ ⟨[1], h1⟩
  rw [entryRecLt_prod2_iff rangeNode (unitClosure 0 1) (unitClosure_nSubfree 0 1),
    neBounded_singleton_pieces 0 h0 hr0 hqe, neBounded_singleton_pieces 1 h1 hr1 hqe]
  exact Or.inl hrlt

/-- Singleton heads compare by code: the head blocks of the nonempty-collapse
row are enumerated in code order. -/
theorem headRank_lt_iff {cx cy : Code} (hcx : cx ≤ 1) (hcy : cy ≤ 1)
    (hx : denotes neBounded [cx]) (hy : denotes neBounded [cy]) :
    entryRank neBounded ⟨[cx], hx⟩ < entryRank neBounded ⟨[cy], hy⟩ ↔ cx < cy := by
  interval_cases cx <;> interval_cases cy
  · exact iff_of_false (lt_irrefl _) (by omega)
  · exact iff_of_true (neBounded_headRank_lt hx hy) (by omega)
  · exact iff_of_false (lt_asymm (neBounded_headRank_lt hy hx)) (by omega)
  · exact iff_of_false (lt_irrefl _) (by omega)

/-- Singleton heads with equal rank are the same code: the head block index
is injective. -/
theorem headRank_eq_iff {cx cy : Code} (hx : denotes neBounded [cx])
    (hy : denotes neBounded [cy]) :
    entryRank neBounded ⟨[cx], hx⟩ = entryRank neBounded ⟨[cy], hy⟩ ↔ cx = cy := by
  constructor
  · intro h
    have hval := congrArg Subtype.val
      (entryRank_injective neBounded neBounded_nSubfree h)
    exact ((List.cons.injEq cx [] cy []).mp hval).1
  · rintro rfl; rfl

/-- Headline: the doc-literal collapse row -- nonempty cofinite factors
collide at every split, the least split pins the prefix to one code, and
the type collapses to `omega * k` with `k = 2` the alphabet size:
`cofinite_collision_collapses` read off the real term. -/
theorem neCollapseRow_prodLt_type :
    Ordinal.type (prodLt neBounded neBounded) = ω * 2 := by
  rw [Ordinal.type_eq.mpr ⟨neCollapseIso⟩, type_prod_lex]
  show entriesType neBounded * entriesType rangeNode = ω * 2
  rw [neBounded_entriesType, rangeNode_entriesType]

/- ================================================================ -/
/- 5e: the five transfinite rows, restated over the recursive order.  -/
/- ================================================================ -/

/-- Headline: `{b,c}{a..}` at omega*2 on the recursive order -- a finite
front factor over an omega block is two full recursive blocks, most
significant digit on the left. -/
theorem twoBlocks_entryRecType :
    entryRecType (prod2 twoFaces (unitClosure 0 1)) = ω * 2 := by
  rw [entryRecType_prod2 twoFaces (unitClosure 0 1) twoFaces_nSubfree
      (unitClosure_nSubfree 0 1)
      (fun _ _ _ h h' => twoBlocks_splits_unique h h'),
    unitClosure_entryRecType 0 1 (by omega), twoFaces_entryRecType]

/-- Headline: the seam row at omega^2 on the recursive order -- the doc's
`{b}{a..}{b}{a..}` two-factor with the marker closing the first block.
Splits are pinned by the marker outside the range. -/
theorem seamRow_entryRecType :
    entryRecType (prod2 markedBlock (unitClosure 0 1)) = ω ^ (2 : Ordinal) := by
  rw [entryRecType_prod2 markedBlock (unitClosure 0 1) markedBlock_nSubfree
      (unitClosure_nSubfree 0 1)
      (fun _ _ _ h h' => seamRow_splits_unique h h'),
    unitClosure_entryRecType 0 1 (by omega), markedBlock_entryRecType,
    show (2 : Ordinal) = 1 + 1 by norm_num, opow_add, opow_one]

/-- Headline: the union row at omega + 2 on the recursive order -- a braced
closure with a disjoint two-face tail, the doc's "union alone gives omega
plus a finite tail" on real syntax. The braced closure keeps its enumeration
(`entryRecType_fold_binder`), the tail is disjoint. -/
theorem unionRow_entryRecType :
    entryRecType (napp (braced (unitClosure 0 1)) twoFaces) = ω + 2 := by
  have hdisj : ∀ s, denotes (braced (unitClosure 0 1)) s → ¬ denotes twoFaces s := by
    intro s h1 h2
    rw [braced_denotes_iff _ (unitClosure_bindsb 0 1)] at h1
    have hcodes := (unitClosure01_denotes s).mp h1
    rcases (twoFaces_denotes_iff s).mp h2 with rfl | rfl
    · have := hcodes 2 (by simp); omega
    · have := hcodes 3 (by simp); omega
  have hbr : nSubfree (braced (unitClosure 0 1)) = true := by
    simp [braced, nsingle, nSubfree, mSubfree, unitClosure_nSubfree]
  rw [entryRecType_napp_disjoint (braced (unitClosure 0 1)) twoFaces
      (braced_bindsb _) twoFaces_bindsb hbr twoFaces_nSubfree hdisj]
  show entryRecType (nsingle (.fold (unitClosure 0 1))) + entryRecType twoFaces = ω + 2
  rw [entryRecType_fold_binder (unitClosure 0 1) (unitClosure_bindsb 0 1)
      (unitClosure_nSubfree 0 1),
    unitClosure_entryRecType 0 1 (by omega), twoFaces_entryRecType]

/-- The empty spelling lives in both closure factors, so every entry of the
double closure has all codes bounded and is itself a closure entry. -/
theorem collapseRow_denotes_c
    (e : Entries (prod2 (unitClosure 0 1) (unitClosure 0 1))) :
    denotes (unitClosure 0 1) e.1 := by
  obtain ⟨p, q, heq, hp, hq⟩ := (prod2_denotes_iff _ _ _).mp e.2
  refine (unitClosure01_denotes e.1).mpr ?_
  rw [heq]
  intro d hd
  rcases List.mem_append.mp hd with h | h
  · exact (unitClosure01_denotes p).mp hp d h
  · exact (unitClosure01_denotes q).mp hq d h

/-- The recursion's split choice on the collapse row is the collision split
`([], e.1)`: the empty head loses positionally to nothing, so it owns the
entry -- the recursive-order face of `collapseRow_leastSplit`. -/
theorem collapseRow_someSplit
    (e : Entries (prod2 (unitClosure 0 1) (unitClosure 0 1))) :
    someSplit (unitClosure 0 1) (prodNode (.node (unitClosure 0 1) .nil)) e.1
      = ([], e.1) := by
  refine someSplit_eq (unitClosure 0 1) (prodNode (.node (unitClosure 0 1) .nil))
    ⟨(List.nil_append e.1).symm, (unitClosure01_denotes []).mpr (by simp),
      (prodTail_denotes_iff (unitClosure 0 1) e.1).mpr (collapseRow_denotes_c e)⟩ ?_
  rintro ⟨p, q⟩ ⟨heq, hp, -⟩
  cases p with
  | nil =>
      left
      simp only [List.nil_append] at heq
      rw [heq]
  | cons c rest =>
      right
      exact Prod.lex_def.mpr (Or.inl (List.Shortlex.of_length_lt (by simp)))

/-- On the collapse row the recursive order is the closure's own recursive
order: collision ownership erases the product structure, so the double
closure recurses exactly as the single one. -/
noncomputable def collapseRowRecIso :
    entryRecLt (prod2 (unitClosure 0 1) (unitClosure 0 1))
      ≃r entryRecLt (unitClosure 0 1) where
  toEquiv := Equiv.ofBijective (fun e => ⟨e.1, collapseRow_denotes_c e⟩) (by
    constructor
    · intro x y hxy
      have h := congrArg Subtype.val hxy
      exact Subtype.ext h
    · rintro ⟨s, hs⟩
      have hd : denotes (prod2 (unitClosure 0 1) (unitClosure 0 1)) s :=
        (prod2_denotes_iff _ _ _).mpr ⟨[], s, (List.nil_append s).symm,
          (unitClosure01_denotes []).mpr (by simp), hs⟩
      exact ⟨⟨s, hd⟩, Subtype.ext rfl⟩)
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply]
    rw [entryRecLt_prod2_iff (unitClosure 0 1) (unitClosure 0 1)
      (unitClosure_nSubfree 0 1) x y]
    have htailx : (prod2RecPieces (unitClosure 0 1) (unitClosure 0 1) x).2
        = ⟨x.1, collapseRow_denotes_c x⟩ :=
      Subtype.ext (congrArg Prod.snd (collapseRow_someSplit x))
    have htaily : (prod2RecPieces (unitClosure 0 1) (unitClosure 0 1) y).2
        = ⟨y.1, collapseRow_denotes_c y⟩ :=
      Subtype.ext (congrArg Prod.snd (collapseRow_someSplit y))
    have hheq : entryRank (unitClosure 0 1)
          (prod2RecPieces (unitClosure 0 1) (unitClosure 0 1) x).1
        = entryRank (unitClosure 0 1)
          (prod2RecPieces (unitClosure 0 1) (unitClosure 0 1) y).1 := by
      congr 1
      exact Subtype.ext ((congrArg Prod.fst (collapseRow_someSplit x)).trans
        (congrArg Prod.fst (collapseRow_someSplit y)).symm)
    rw [htailx, htaily, hheq]
    constructor
    · intro h; exact Or.inr ⟨rfl, h⟩
    · rintro (h | ⟨-, h⟩)
      · exact absurd h (lt_irrefl _)
      · exact h

/-- Headline: real-syntax collision collapse on the recursive order. The
double closure's pre-collision recursive type would be `omega * omega`, but
the empty spelling forces every entry onto the collision split `([], s)`, so
the surviving enumeration is the closure's own `omega` -- the doc's "the
least split pins the prefix ... and the type collapses", in the extreme form
the empty spelling forces. -/
theorem collapseRow_entryRecType :
    entryRecType (prod2 (unitClosure 0 1) (unitClosure 0 1)) = ω := by
  have hcsub : nSubfree (unitClosure 0 1) = true := unitClosure_nSubfree 0 1
  have hsub : nSubfree (prod2 (unitClosure 0 1) (unitClosure 0 1)) = true := by
    simp [prod2, nsingle, nSubfree, mSubfree, fSubfree, hcsub]
  haveI := entryRecLt_isWellOrder (prod2 (unitClosure 0 1) (unitClosure 0 1)) hsub
  haveI := entryRecLt_isWellOrder (unitClosure 0 1) hcsub
  rw [entryRecType_def (prod2 (unitClosure 0 1) (unitClosure 0 1)) hsub,
    Ordinal.type_eq.mpr ⟨collapseRowRecIso⟩,
    ← entryRecType_def (unitClosure 0 1) hcsub, unitClosure_entryRecType 0 1 (by omega)]

/- ---------------------------------------------------------------- -/
/- The nonempty-factor collapse row {a..}{a..} on the recursive       -/
/- order: omega * 4, not omega * 2. See the k-shift note below.       -/
/- ---------------------------------------------------------------- -/

/-- The recursion's split choice on the nonempty-collapse row is the
collision split `([c], t)`: the shortest nonempty head owns the entry --
the recursive-order face of `neCollapse_leastSplit`. -/
theorem neCollapse_someSplit (c : Code) (t : Spelling)
    (e : Entries (prod2 neBounded neBounded)) (heq : e.1 = c :: t) :
    someSplit neBounded (prodNode (.node neBounded .nil)) e.1 = ([c], t) := by
  have hc : c ≤ 1 := neCollapse_codes e c (by rw [heq]; exact List.mem_cons_self)
  have ht : t ≠ [] := by
    have hlen := neCollapse_len e
    rw [heq] at hlen
    simp only [List.length_cons] at hlen
    intro h; subst h; simp at hlen
  refine someSplit_eq neBounded (prodNode (.node neBounded .nil))
    ⟨by rw [heq]; rfl,
      (neBounded_denotes_iff [c]).mpr ⟨by simp,
        fun d hd => by rw [List.mem_singleton.mp hd]; exact hc⟩,
      (prodTail_denotes_iff neBounded t).mpr
        ((neBounded_denotes_iff t).mpr ⟨ht,
          fun d hd => neCollapse_codes e d
            (by rw [heq]; exact List.mem_cons_of_mem c hd)⟩)⟩
    ?_
  rintro ⟨p, q⟩ ⟨hpq, hp, -⟩
  have hpne := ((neBounded_denotes_iff p).mp hp).1
  obtain ⟨c', rest, rfl⟩ : ∃ c' rest, p = c' :: rest := by
    cases p with
    | nil => exact absurd rfl hpne
    | cons c' rest => exact ⟨c', rest, rfl⟩
  cases rest with
  | nil =>
      left
      have h2 : c :: t = c' :: q := heq.symm.trans hpq
      obtain ⟨rfl, rfl⟩ := (List.cons.injEq _ _ _ _).mp h2
      rfl
  | cons d rest' =>
      right
      exact Prod.lex_def.mpr (Or.inl (List.Shortlex.of_length_lt
        (by simp only [List.length_cons, List.length_nil]; omega)))

/-- Every nonempty-collapse entry is its head code consed onto its tail. -/
theorem neCollapse_cons (e : Entries (prod2 neBounded neBounded)) :
    e.1 = e.1.headI :: e.1.tail := by
  obtain ⟨c, t, hct⟩ : ∃ c t, e.1 = c :: t := by
    have hlen := neCollapse_len e
    cases h : e.1 with
    | nil => rw [h] at hlen; simp at hlen
    | cons c t => exact ⟨c, t, rfl⟩
  rw [hct]

theorem neCollapse_head_le (e : Entries (prod2 neBounded neBounded)) :
    e.1.headI ≤ 1 := by
  refine neCollapse_codes e e.1.headI ?_
  conv_rhs => rw [neCollapse_cons e]
  exact List.mem_cons_self

theorem neCollapse_tail_mem (e : Entries (prod2 neBounded neBounded)) :
    denotes neBounded e.1.tail := by
  refine (neBounded_denotes_iff _).mpr ⟨?_, ?_⟩
  · intro h
    have hlen := neCollapse_len e
    rw [neCollapse_cons e, h] at hlen
    simp at hlen
  · intro d hd
    refine neCollapse_codes e d ?_
    conv_rhs => rw [neCollapse_cons e]
    exact List.mem_cons_of_mem _ hd

/-- The nonempty-collapse row recurses as a two-block head over the tail
body's own recursive order: `Fin 2` (the two range codes) lex the whole
`neBounded` tail order. -/
noncomputable def neCollapseRecIso :
    entryRecLt (prod2 neBounded neBounded)
      ≃r Prod.Lex ((· < ·) : Fin 2 → Fin 2 → Prop) (entryRecLt neBounded) where
  toEquiv := Equiv.ofBijective (fun e =>
    (⟨e.1.headI, Nat.lt_succ_of_le (neCollapse_head_le e)⟩,
     ⟨e.1.tail, neCollapse_tail_mem e⟩)) (by
    constructor
    · intro x y hxy
      simp only [Prod.mk.injEq, Fin.mk.injEq, Subtype.mk.injEq] at hxy
      apply Subtype.ext
      rw [neCollapse_cons x, neCollapse_cons y, hxy.1, hxy.2]
    · rintro ⟨⟨i, hi⟩, ⟨q, hq⟩⟩
      have hi1 : i ≤ 1 := by omega
      have hbi : denotes neBounded [i] :=
        (neBounded_denotes_iff [i]).mpr ⟨by simp,
          fun d hd => by rw [List.mem_singleton.mp hd]; exact hi1⟩
      have hd : denotes (prod2 neBounded neBounded) (i :: q) :=
        (prod2_denotes_iff _ _ _).mpr ⟨[i], q, rfl, hbi, hq⟩
      exact ⟨⟨i :: q, hd⟩, Prod.ext (Fin.ext rfl) (Subtype.ext rfl)⟩)
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply, Prod.lex_def, Fin.mk_lt_mk, Fin.mk.injEq]
    rw [entryRecLt_prod2_iff neBounded neBounded neBounded_nSubfree x y]
    have hpinx : someSplit neBounded (prodNode (.node neBounded .nil)) x.1
        = ([x.1.headI], x.1.tail) :=
      neCollapse_someSplit x.1.headI x.1.tail x (neCollapse_cons x)
    have hpiny : someSplit neBounded (prodNode (.node neBounded .nil)) y.1
        = ([y.1.headI], y.1.tail) :=
      neCollapse_someSplit y.1.headI y.1.tail y (neCollapse_cons y)
    have hmemx : denotes neBounded [x.1.headI] :=
      (neBounded_denotes_iff _).mpr ⟨by simp,
        fun d hd => by rw [List.mem_singleton.mp hd]; exact neCollapse_head_le x⟩
    have hmemy : denotes neBounded [y.1.headI] :=
      (neBounded_denotes_iff _).mpr ⟨by simp,
        fun d hd => by rw [List.mem_singleton.mp hd]; exact neCollapse_head_le y⟩
    have hhx : (prod2RecPieces neBounded neBounded x).1 = ⟨[x.1.headI], hmemx⟩ :=
      Subtype.ext (congrArg Prod.fst hpinx)
    have hhy : (prod2RecPieces neBounded neBounded y).1 = ⟨[y.1.headI], hmemy⟩ :=
      Subtype.ext (congrArg Prod.fst hpiny)
    have htx : (prod2RecPieces neBounded neBounded x).2
        = ⟨x.1.tail, neCollapse_tail_mem x⟩ :=
      Subtype.ext (congrArg Prod.snd hpinx)
    have hty : (prod2RecPieces neBounded neBounded y).2
        = ⟨y.1.tail, neCollapse_tail_mem y⟩ :=
      Subtype.ext (congrArg Prod.snd hpiny)
    rw [hhx, hhy, htx, hty,
      headRank_lt_iff (neCollapse_head_le x) (neCollapse_head_le y) hmemx hmemy,
      headRank_eq_iff hmemx hmemy]

/-- Headline: the nonempty-factor collapse row `{a..}{a..}` on the recursive
order enumerates at `omega * 4` -- NOT `omega * 2`. The doc's claim is
"collapses to omega*k, k finite", and it stands with k = 4.

The k-shift from the spelling-order approximation (which gave k = 2): the
survivors are still the two head blocks the alphabet `{0, 1}` supplies, but
each block is now enumerated by the *tail* body's own recursive order.
`neBounded = {a..}` has unique splits, so its recursive type is the
positional `entryRecType (unitClosure 0 1) * entryRecType rangeNode = omega*2`
(two lead blocks), where the spelling order interleaved those into one omega.
The row is therefore `(omega*2) * 2 = omega*4` (2 heads times 2 tail
lead-blocks) rather than `omega*2`. -/
theorem neCollapseRow_entryRecType :
    entryRecType (prod2 neBounded neBounded) = ω * 4 := by
  have hsub : nSubfree (prod2 neBounded neBounded) = true := by
    simp [prod2, nsingle, nSubfree, mSubfree, fSubfree, neBounded_nSubfree]
  haveI := entryRecLt_isWellOrder (prod2 neBounded neBounded) hsub
  haveI := entryRecLt_isWellOrder neBounded neBounded_nSubfree
  rw [entryRecType_def (prod2 neBounded neBounded) hsub,
    Ordinal.type_eq.mpr ⟨neCollapseRecIso⟩,
    type_prod_lex ((· < ·) : Fin 2 → Fin 2 → Prop) (entryRecLt neBounded),
    ← entryRecType_def neBounded neBounded_nSubfree, neBounded_entryRecType,
    show Ordinal.type ((· < ·) : Fin 2 → Fin 2 → Prop) = ((2 : ℕ) : Ordinal)
      from type_fin 2, mul_assoc]
  norm_num

end L1
