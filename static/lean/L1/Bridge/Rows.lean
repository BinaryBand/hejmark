/- L1 bridge: the transfinite rows -- entry types past omega on real syntax,
under the body-recursive order (`RecOrder.lean`'s `entryRecType`).

`docs/foundation/L1.md` (Bounded transfinitude): "union alone gives omega
plus a finite tail; product climbs -- `{b,c}{a..}` is omega*2,
`{b}{a..}{b}{a..}` is omega^2 ... In `{a..}{a..}` the least split pins the
prefix ... and the type collapses." This file computes those rows over the
real syntax, through the recursive within-body order: `entryRecType_prod2`
(the positional product law, under unique splits) and
`entryRecType_napp_disjoint` (the disjoint union sum). The codes are fixed
small numerals: the omega factor is `unitClosure 0 1` (every spelling over
`{0, 1}`), and the unique-split rows draw their front faces and seam marker
from `2` and `3` -- outside the closure range, so the marker pins each
split. The in-range seam row at the end of the file instead draws its
marker from *inside* the range, where the splits genuinely collide.

- `collapseRow_entryRecType` (`{a..}{a..}`-extreme, type omega): with the
  empty spelling in both factors every entry is claimed by the collision
  split `([], s)`, so the recursion runs the closure's own order -- the
  pre-collision omega*omega collapses all the way to one omega.
- `twoBlocks_entryRecType` (`{b,c}{a..}`, type omega*2): the front faces
  sit outside the closure range, splits are unique, and the recursive
  enumeration is the ordinal product -- two full omega-blocks.
- `seamRow_entryRecType` (type omega^2): the doc's `{b}{a..}{b}{a..}`
  written two-factor, with the marker `2` closing the first block
  (`markedBlock`). The marker is outside the closure range so each
  spelling splits at its unique marker.
- `inSeamRow_entryRecType` (type omega^2, marker in range): the same seam
  row with the marker `1` drawn from the closure range, the doc-faithful
  reading of `{b}{a..}{b}{a..}` where `b` is itself an `{a..}` entry. The
  splits genuinely collide (`inSeamRow_splits_collide`), the recursion
  keeps each entry's first-marker split -- the marker-free head `0^k`
  closed by the seam character (`inSeamRow_survivor`, the doc's "every
  pair with a `b`-free first segment is its own least split") -- those
  heads stand cofinally with a full omega block each, and omega^2 still
  stands: phase F's `seam_collision_survives`, landed on real syntax.
- `unionRow_entryRecType` (type omega + 2): a braced closure with a
  two-face tail -- the union enumeration continues past the limit, the
  doc's "omega plus a finite tail" on real syntax.
- `neCollapseRow_entryRecType` (`{a..}{a..}` with nonempty factors, type
  **omega*4**): the doc-literal cofinite collision row. Splits collide
  everywhere and the recursion's least split pins the prefix to one code,
  so exactly two head blocks survive -- but under the recursive order each
  block is enumerated by the *tail* body's own two-lead-block recursive
  order (`neBounded_entryRecType = omega*2`, where the spelling-order
  approximation gave omega). The row is therefore `(omega*2)*2 = omega*4`,
  a k-shift from the approximation's `omega*2`; the doc's "collapses to
  omega*k, k finite" stands with k = 4. -/
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
/- The two-blocks row {b,c}{a..}: omega * 2.                         -/
/- ---------------------------------------------------------------- -/

/-- The two-face front factor `{b,c}`: codes `2` and `3`, outside the
closure range. -/
def twoFaces : Node := .cons (.face [2]) (nsingle (.face [3]))

theorem twoFaces_bindsb : bindsb twoFaces = false := rfl

theorem twoFaces_denotes_iff (s : Spelling) :
    denotes twoFaces s ↔ s = [2] ∨ s = [3] := by
  show ndenote twoFaces (fun _ => False) s ↔ _
  rw [ndenote_nonbinder _ _ _ twoFaces_bindsb]
  show walk (.cons (.face [2]) (nsingle (.face [3]))) _ False s ↔ _
  rw [walk_cons, walk_single_face, walk_single_face]
  tauto

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
Splits are pinned by the marker outside the range; the colliding in-range
marker version is `inSeamRow_entryRecType` at the end of the file. -/
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
entry -- the collision-ownership rule of `prod2_collision_settled` read off
the collapse row. -/
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
the doc's "the least split pins the prefix", on the recursive order. -/
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
  rw [hct]; rfl

theorem neCollapse_head_le (e : Entries (prod2 neBounded neBounded)) :
    e.1.headI ≤ 1 := by
  apply neCollapse_codes e
  have h : e.1.headI ∈ e.1.headI :: e.1.tail := List.mem_cons_self
  rwa [← neCollapse_cons e] at h

theorem neCollapse_tail_mem (e : Entries (prod2 neBounded neBounded)) :
    denotes neBounded e.1.tail := by
  refine (neBounded_denotes_iff _).mpr ⟨?_, ?_⟩
  · intro h
    have hlen := neCollapse_len e
    rw [neCollapse_cons e, h] at hlen
    simp at hlen
  · intro d hd
    apply neCollapse_codes e
    have h : d ∈ e.1.headI :: e.1.tail := List.mem_cons_of_mem _ hd
    rwa [← neCollapse_cons e] at h

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
    exact Iff.rfl

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
    Ordinal.type_eq.mpr ⟨neCollapseRecIso⟩, type_prod_lex,
    ← entryRecType_def neBounded neBounded_nSubfree, neBounded_entryRecType]
  have hfin : Ordinal.type ((· < ·) : Fin 2 → Fin 2 → Prop) = 2 := by
    rw [type_fin]; norm_num
  rw [hfin, mul_assoc]
  norm_num

/- ---------------------------------------------------------------- -/
/- WP1: the promotion is conservative where it was meant to be, and  -/
/- exercised where it was meant to bite. See RecOrder.design.md WP1. -/
/- ---------------------------------------------------------------- -/

/-- **Anti-divergence for the nested-closure promotion.** On a node with no
closure nested below it (`ncFreeb`), the shipped body-recursive rank is exactly
the rank the same recursion gives when run at the old stage-major fallback
oracle (`clFallbackRank` / `clFallbackBound`, the `typein (entryLt _)` the
within-stage recursion used before WP1).

So the promotion cannot silently have moved anything it was not supposed to
move: wherever no closure is nested, the order is the one that shipped before.
The oracle is simply never consulted, which is what the locality congruence
lemmas turn into an equality without inspecting either recursion. -/
theorem entryRank_promotion_agree (n : Node) (hb : bindsb n = false)
    (hnc : ncFreeb n = true) (e : Entries n) :
    entryRank n e
      = wnRank noAmp noAmpRank 0 clFallbackRank clFallbackBound n
          ⟨e.1, (ndenote_nonbinder n noAmp e.1 hb).mp e.2⟩ := by
  show nRank n e = _
  rw [nRank_nb hb e ((ndenote_nonbinder n noAmp e.1 hb).mp e.2)]
  exact wnRank_cl_congr noAmp noAmpRank 0 (fun _ => False)
    cRank clFallbackRank cBound clFallbackBound
    (fun _ _ h => h.elim) (fun _ h => h.elim) n (nSites_of_ncFreeb n hnc) _

/- ---- The witness: a row that genuinely nests a closure. ---- -/

/-- A row that nests a closure inside a *stage body* -- the shape WP1 promoted.

Two things have to hold at once. The node must **bind** (its product carries a
bare `&`), so its entries rank through the closure ladder and its body is
walked by the within-stage recursion at `amp := stage n k`. And a closure must
occur **below** it (`ncFreeb = false`): here the brace factor
`{unitClosure 0 1}` is a fold-of-binder, so ranking the body consults the
oracle. That consultation is what used to be `typein (entryLt _)` and is now
`cRank`.

Existing terms have at most one of the two. `unitClosure`, `anbn`, `abab`,
`btrees`, `numerals_body` and `unguarded_fill` bind but are nested-closure-free;
`numerals`, `braced (unitClosure 0 1)` and `neBounded` do consult the oracle but
do not bind, so the consultation happens at the top level, where 4d-iii had
already routed it to `cRank` before WP1. This row is the first term where the
consultation happens inside a stage body. -/
def nestedClosureRow : Node :=
  nsingle (.prod (.node (braced (unitClosure 0 1)) (.amp .nil)))

/-- The witness really is one: it binds *and* consults the closure oracle below
itself, so the consultation happens inside a stage body. Both halves are needed
-- either alone is satisfied by pre-existing rows. Being outside `ncFreeb`, it
is also exactly the case the agreement lemma above does *not* cover: a term
where the promotion genuinely changed the order. -/
theorem nestedClosureRow_is_wp1_shape :
    bindsb nestedClosureRow = true ∧ ncFreeb nestedClosureRow = false :=
  ⟨rfl, rfl⟩

theorem nestedClosureRow_nSubfree : nSubfree nestedClosureRow = true := by
  simp [nestedClosureRow, nsingle, nSubfree, mSubfree, fSubfree, braced,
    unitClosure_nSubfree]

/-- **The promoted order is a genuine well order on a term that exercises the
promotion.** Getting here runs faithfulness through the body-recursive
nested-closure branch: the stage-body rank of the brace factor is discharged by
`cFaithful` at the nested subterm, where before WP1 it was `typein` of the
stage-major fallback. This is the regression witness the promoted path
previously had nowhere to be tested on. -/
theorem nestedClosureRow_entryRecLt_isWellOrder :
    IsWellOrder (Entries nestedClosureRow) (entryRecLt nestedClosureRow) :=
  entryRecLt_isWellOrder nestedClosureRow nestedClosureRow_nSubfree

/- ================================================================ -/
/- The in-range seam row: the marker lives in the closure range, the -/
/- splits genuinely collide, and omega^2 still stands.               -/
/-                                                                   -/
/- The doc's `{b}{a..}{b}{a..}` has its seam character `b` inside     -/
/- the `{a..}` factors, so a spelling with several `b`s is claimed    -/
/- by several splits and the collision rule must drop all but the     -/
/- least. `seamRow_entryRecType` above dodged that by moving the      -/
/- marker out of range; this section keeps it in range (`1`, a        -/
/- closure code) and runs the recursion's own split choice            -/
/- (`someSplit`) through the collision: the least split cuts at the   -/
/- FIRST marker, so the surviving heads are exactly the marker-free   -/
/- runs `0^k` closed by the seam character -- phase F's               -/
/- `bfree_survives`, on real syntax -- and they stand cofinally with  -/
/- a full omega block of tails each: omega^2 survives the collision.  -/
/- ================================================================ -/

/-- The in-range marked block: bounded strings closed by the marker `1` --
`markedBlock` with the seam character drawn from the closure range. -/
def inSeamBlock : Node := prod2 (unitClosure 0 1) (nsingle (.face [1]))

theorem inSeamBlock_denotes_iff (s : Spelling) :
    denotes inSeamBlock s ↔ ∃ u, s = u ++ [1] ∧ ∀ c ∈ u, c ≤ 1 := by
  show denotes (prod2 (unitClosure 0 1) (nsingle (.face [1]))) s ↔ _
  rw [prod2_denotes_iff]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    rw [face_denotes_iff] at hq
    subst hq
    exact ⟨p, rfl, (unitClosure01_denotes p).mp hp⟩
  · rintro ⟨u, rfl, hu⟩
    exact ⟨u, [1], rfl, (unitClosure01_denotes u).mpr hu,
      (face_denotes_iff _ _).mpr rfl⟩

/-- The block's own splits stay unique -- the face tail pins the cut point
regardless of where the marker code lives (`markedBlock_splits_unique`'s
argument, unchanged). The collision below is a row-level phenomenon. -/
theorem inSeamBlock_splits_unique {s : Spelling} {pq pq' : Spelling × Spelling}
    (h : IsSplit (unitClosure 0 1) (nsingle (.face [1])) s pq)
    (h' : IsSplit (unitClosure 0 1) (nsingle (.face [1])) s pq') : pq = pq' := by
  obtain ⟨heq, -, hq⟩ := h
  obtain ⟨heq', -, hq'⟩ := h'
  rw [face_denotes_iff] at hq hq'
  obtain ⟨h1, h2⟩ := List.append_inj' (heq.symm.trans heq') (by rw [hq, hq'])
  exact Prod.ext h1 h2

theorem inSeamBlock_nSubfree : nSubfree inSeamBlock = true := by
  simp [inSeamBlock, prod2, nsingle, nSubfree, mSubfree, fSubfree,
    unitClosure_nSubfree]

/-- The in-range marked block under the recursive order: a full omega of
bounded prefixes, one marker entry each. -/
theorem inSeamBlock_entryRecType : entryRecType inSeamBlock = ω := by
  show entryRecType (prod2 (unitClosure 0 1) (nsingle (.face [1]))) = ω
  rw [entryRecType_prod2 (unitClosure 0 1) (nsingle (.face [1]))
      (unitClosure_nSubfree 0 1) rfl
      (fun _ _ _ h h' => inSeamBlock_splits_unique h h'),
    face_entryRecType, unitClosure_entryRecType 0 1 (by omega), one_mul]

/-- The seams genuinely collide: the spelling `11` is claimed by two
distinct splits, `1 | 1` and `11 | empty` -- the unique-split hypothesis of
`entryRecType_prod2` is unavailable on this row, so the omega^2 headline
below cannot ride the positional product law and has to survive the
collision rule instead. Phase F's colliding pairs, on real cuts. -/
theorem inSeamRow_splits_collide :
    ∃ (s : Spelling) (pq pq' : Spelling × Spelling), pq ≠ pq' ∧
      IsSplit inSeamBlock (unitClosure 0 1) s pq ∧
      IsSplit inSeamBlock (unitClosure 0 1) s pq' := by
  refine ⟨[1, 1], ([1], [1]), ([1, 1], []), by decide,
    ⟨rfl, ?_, ?_⟩, ⟨(List.append_nil _).symm, ?_, ?_⟩⟩
  · exact (inSeamBlock_denotes_iff [1]).mpr ⟨[], rfl, by simp⟩
  · exact (unitClosure01_denotes [1]).mpr (by simp)
  · exact (inSeamBlock_denotes_iff [1, 1]).mpr ⟨[1], rfl, by simp⟩
  · exact (unitClosure01_denotes []).mpr (by simp)

/- ---- The marker-free run and the first-marker cut. ---- -/

/-- `k` zeros: over the two-code alphabet a marker-free bounded segment is
exactly such a run -- the real-syntax shape of phase F's `b`-free
`List.replicate` spellings. -/
def zeros (k : ℕ) : Spelling := List.replicate k 0

theorem zeros_length (k : ℕ) : (zeros k).length = k := by simp [zeros]

theorem one_not_mem_zeros (k : ℕ) : (1 : Code) ∉ zeros k := fun h => by
  simpa using List.eq_of_mem_replicate h

theorem zeros_bounded (k : ℕ) : ∀ c ∈ zeros k, c ≤ 1 := fun c hc => by
  rw [List.eq_of_mem_replicate hc]
  omega

/-- A bounded marker-free segment is a run of zeros. -/
theorem zeros_of_marker_free {z : Spelling} (hb : ∀ c ∈ z, c ≤ 1)
    (hz : (1 : Code) ∉ z) : z = zeros z.length := by
  show z = List.replicate z.length 0
  rw [List.eq_replicate_length]
  intro b hbz
  have h1 := hb b hbz
  have h2 : b ≠ 1 := fun h => hz (h ▸ hbz)
  omega

/-- Every spelling wearing the marker cuts at its first occurrence, with a
marker-free prefix. -/
theorem first_marker_split {s : Spelling} (h : (1 : Code) ∈ s) :
    ∃ z v, s = z ++ 1 :: v ∧ (1 : Code) ∉ z := by
  induction s with
  | nil => cases h
  | cons c rest ih =>
      by_cases hc : c = 1
      · subst hc
        exact ⟨[], rest, rfl, by simp⟩
      · have hrest : (1 : Code) ∈ rest := by
          rcases List.mem_cons.mp h with h1 | h1
          · exact absurd h1.symm hc
          · exact h1
        obtain ⟨z, v, rfl, hz⟩ := ih hrest
        refine ⟨c :: z, v, rfl, fun hm => ?_⟩
        rcases List.mem_cons.mp hm with h1 | h1
        · exact hc h1.symm
        · exact hz h1

/-- The collision surgery: two first-marker readings of one spelling either
agree or the one with the marker-free prefix is the strictly shorter cut --
the doc's "a shorter prefix would place `b` inside the `b`-free segment"
(`bfree_survives`'s trichotomy, on real lists). -/
theorem seam_least_split {z v u q : Spelling} (hz : (1 : Code) ∉ z)
    (h : z ++ 1 :: v = u ++ 1 :: q) :
    (z = u ∧ v = q) ∨ z.length < u.length := by
  rcases Nat.lt_trichotomy z.length u.length with hlt | heq | hgt
  · exact Or.inr hlt
  · obtain ⟨h1, h2⟩ := List.append_inj h heq
    exact Or.inl ⟨h1, ((List.cons.injEq _ _ _ _).mp h2).2⟩
  · -- A shorter `u` forces the marker into the marker-free `z`.
    exfalso
    have hpre1 : u <+: z ++ 1 :: v := h ▸ List.prefix_append u (1 :: q)
    obtain ⟨t, rfl⟩ := List.prefix_of_prefix_length_le hpre1
      (List.prefix_append z (1 :: v)) (Nat.le_of_lt hgt)
    rw [List.append_assoc] at h
    have htail : t ++ 1 :: v = 1 :: q := List.append_cancel_left h
    cases t with
    | nil => simp at hgt
    | cons th tt =>
        simp only [List.cons_append, List.cons.injEq] at htail
        exact hz (List.mem_append_right u (htail.1 ▸ List.mem_cons_self))

/-- Cut a spelling at its first marker: the length of the marker-free
prefix, and the suffix past the marker (junk on a marker-free spelling). -/
def seamCut : Spelling → ℕ × Spelling
  | [] => (0, [])
  | c :: rest =>
      if c = 1 then (0, rest)
      else ((seamCut rest).1 + 1, (seamCut rest).2)

theorem seamCut_eq {z v : Spelling} (hz : (1 : Code) ∉ z) :
    seamCut (z ++ 1 :: v) = (z.length, v) := by
  induction z with
  | nil => simp [seamCut]
  | cons c rest ih =>
      have hc : c ≠ 1 := fun h => hz (h ▸ List.mem_cons_self)
      have hrest : (1 : Code) ∉ rest := fun h => hz (List.mem_cons_of_mem c h)
      simp [seamCut, hc, ih hrest]

/- ---- The row's entries: bounded spellings wearing the marker. ---- -/

theorem inSeamRow_denotes_iff (s : Spelling) :
    denotes (prod2 inSeamBlock (unitClosure 0 1)) s
      ↔ (1 : Code) ∈ s ∧ ∀ c ∈ s, c ≤ 1 := by
  rw [prod2_denotes_iff]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    obtain ⟨u, rfl, hu⟩ := (inSeamBlock_denotes_iff p).mp hp
    have hq1 := (unitClosure01_denotes q).mp hq
    refine ⟨List.mem_append_left q (List.mem_append_right u List.mem_cons_self), ?_⟩
    intro c hc
    rcases List.mem_append.mp hc with hc1 | hc2
    · rcases List.mem_append.mp hc1 with hcu | hc1'
      · exact hu c hcu
      · rw [List.mem_singleton.mp hc1']
    · exact hq1 c hc2
  · rintro ⟨hm, hcodes⟩
    obtain ⟨z, v, rfl, hz⟩ := first_marker_split hm
    refine ⟨z ++ [1], v, (List.append_assoc z [1] v).symm, ?_, ?_⟩
    · exact (inSeamBlock_denotes_iff _).mpr
        ⟨z, rfl, fun c hc => hcodes c (List.mem_append_left _ hc)⟩
    · exact (unitClosure01_denotes v).mpr
        (fun c hc => hcodes c (List.mem_append_right z (List.mem_cons_of_mem 1 hc)))

/-- Every entry is its first-marker cut: a marker-free run of zeros, the
seam character, the suffix. -/
theorem inSeamRow_cons (e : Entries (prod2 inSeamBlock (unitClosure 0 1))) :
    e.1 = zeros (seamCut e.1).1 ++ 1 :: (seamCut e.1).2 := by
  obtain ⟨hm, hcodes⟩ := (inSeamRow_denotes_iff e.1).mp e.2
  obtain ⟨z, v, hzv, hz⟩ := first_marker_split hm
  have hzb : ∀ c ∈ z, c ≤ 1 := fun c hc =>
    hcodes c (by rw [hzv]; exact List.mem_append_left _ hc)
  rw [hzv, seamCut_eq hz, ← zeros_of_marker_free hzb hz]

theorem inSeamRow_head_denotes (e : Entries (prod2 inSeamBlock (unitClosure 0 1))) :
    denotes inSeamBlock (zeros (seamCut e.1).1 ++ [1]) :=
  (inSeamBlock_denotes_iff _).mpr ⟨zeros (seamCut e.1).1, rfl, zeros_bounded _⟩

theorem inSeamRow_tail_denotes (e : Entries (prod2 inSeamBlock (unitClosure 0 1))) :
    denotes (unitClosure 0 1) (seamCut e.1).2 := by
  obtain ⟨-, hcodes⟩ := (inSeamRow_denotes_iff e.1).mp e.2
  refine (unitClosure01_denotes _).mpr (fun c hc => hcodes c ?_)
  rw [inSeamRow_cons e]
  exact List.mem_append_right _ (List.mem_cons_of_mem 1 hc)

/-- The recursion's split choice under the collision: the least split cuts
at the FIRST marker. A claimant cutting later has a longer head and loses
positionally; one cutting earlier would need a marker inside the
marker-free prefix (`seam_least_split`). This is `someSplit` -- the one
split-choosing primitive -- exercised on genuinely colliding claimants. -/
theorem inSeamRow_someSplit (e : Entries (prod2 inSeamBlock (unitClosure 0 1)))
    {z v : Spelling} (heq : e.1 = z ++ 1 :: v) (hz : (1 : Code) ∉ z) :
    someSplit inSeamBlock (prodNode (.node (unitClosure 0 1) .nil)) e.1
      = (z ++ [1], v) := by
  obtain ⟨-, hcodes⟩ := (inSeamRow_denotes_iff e.1).mp e.2
  have hzb : ∀ c ∈ z, c ≤ 1 := fun c hc =>
    hcodes c (by rw [heq]; exact List.mem_append_left _ hc)
  have hvb : ∀ c ∈ v, c ≤ 1 := fun c hc =>
    hcodes c (by rw [heq]; exact List.mem_append_right z (List.mem_cons_of_mem 1 hc))
  refine someSplit_eq inSeamBlock (prodNode (.node (unitClosure 0 1) .nil))
    ⟨heq.trans (List.append_assoc z [1] v).symm,
      (inSeamBlock_denotes_iff _).mpr ⟨z, rfl, hzb⟩,
      (prodTail_denotes_iff (unitClosure 0 1) v).mpr
        ((unitClosure01_denotes v).mpr hvb)⟩ ?_
  rintro ⟨p, q⟩ ⟨hpq, hp, -⟩
  obtain ⟨u, rfl, -⟩ := (inSeamBlock_denotes_iff p).mp hp
  have hcat : z ++ 1 :: v = u ++ 1 :: q :=
    heq.symm.trans (hpq.trans (List.append_assoc u [1] q))
  rcases seam_least_split hz hcat with ⟨rfl, rfl⟩ | hlt
  · left
    rfl
  · right
    refine Prod.lex_def.mpr (Or.inl (List.Shortlex.of_length_lt ?_))
    simp only [List.length_append, List.length_cons, List.length_nil]
    omega

/-- The survivors on real syntax: the recursion carves every entry at its
first-marker split, so the head it keeps is the marker-free run `0^k`
closed by the seam character -- the doc's "every pair with a `b`-free
first segment is its own least split", read off `prod2RecPieces`. -/
theorem inSeamRow_survivor (e : Entries (prod2 inSeamBlock (unitClosure 0 1))) :
    prod2RecPieces inSeamBlock (unitClosure 0 1) e
      = (⟨zeros (seamCut e.1).1 ++ [1], inSeamRow_head_denotes e⟩,
         ⟨(seamCut e.1).2, inSeamRow_tail_denotes e⟩) := by
  have hpin := inSeamRow_someSplit e (inSeamRow_cons e) (one_not_mem_zeros _)
  exact Prod.ext (Subtype.ext (congrArg Prod.fst hpin))
    (Subtype.ext (congrArg Prod.snd hpin))

/- ---- Head blocks in run-length order. ---- -/

/-- On the demotion row the recursive rank is length-monotone: a strictly
shorter entry first-appears strictly earlier, so stage-major disjointness
(`cRank_lt_of_firstStage_lt`) puts it strictly below. -/
theorem unitClosure_entryRank_lt_of_length_lt {x y : Entries (unitClosure 0 1)}
    (h : x.1.length < y.1.length) :
    entryRank (unitClosure 0 1) x < entryRank (unitClosure 0 1) y := by
  have hstage : ∀ e : Entries (unitClosure 0 1),
      stage (unitClosure 0 1) (firstStage (unitClosure 0 1) e.1) e.1 := fun e =>
    firstStage_stage _ e.1
      ((ndenote_binder _ (fun _ => False) e.1 (unitClosure_bindsb 0 1)).mp e.2)
  rw [entryRank_binder _ (unitClosure_bindsb 0 1) x,
    entryRank_binder _ (unitClosure_bindsb 0 1) y]
  refine cRank_lt_of_firstStage_lt _ (unitClosure_nSubfree 0 1)
    (hstage x) (hstage y) ?_
  rw [unitClosure_firstStage 0 1 x.1 ((unitClosure_generates 0 1 x.1).mp x.2),
    unitClosure_firstStage 0 1 y.1 ((unitClosure_generates 0 1 y.1).mp y.2)]
  omega

/-- The surviving heads' pieces inside the block: the block's splits are
unique, so the recursion cuts `0^k 1` into the run and the face. -/
theorem inSeamBlock_headPieces (k : ℕ) (h : denotes inSeamBlock (zeros k ++ [1]))
    (hp : denotes (unitClosure 0 1) (zeros k))
    (hq : denotes (nsingle (.face [1])) [1]) :
    prod2RecPieces (unitClosure 0 1) (nsingle (.face [1])) ⟨zeros k ++ [1], h⟩
      = (⟨zeros k, hp⟩, ⟨[1], hq⟩) := by
  have hpin : someSplit (unitClosure 0 1)
      (prodNode (.node (nsingle (.face [1])) .nil)) (zeros k ++ [1])
      = (zeros k, [1]) :=
    prod2_someSplit_eq (unitClosure 0 1) (nsingle (.face [1]))
      (fun _ _ _ h1 h2 => inSeamBlock_splits_unique h1 h2) rfl hp hq
  exact Prod.ext (Subtype.ext (congrArg Prod.fst hpin))
    (Subtype.ext (congrArg Prod.snd hpin))

/-- A longer marker-free run is a strictly larger head: the run rides the
closure's length-monotone rank, the face contributes nothing. -/
theorem inSeamBlock_headRank_lt {j k : ℕ} (hjk : j < k)
    (hj : denotes inSeamBlock (zeros j ++ [1]))
    (hk : denotes inSeamBlock (zeros k ++ [1])) :
    entryRank inSeamBlock ⟨zeros j ++ [1], hj⟩
      < entryRank inSeamBlock ⟨zeros k ++ [1], hk⟩ := by
  have hpj : denotes (unitClosure 0 1) (zeros j) :=
    (unitClosure01_denotes _).mpr (zeros_bounded j)
  have hpk : denotes (unitClosure 0 1) (zeros k) :=
    (unitClosure01_denotes _).mpr (zeros_bounded k)
  have hface : denotes (nsingle (.face [1])) [1] := (face_denotes_iff _ _).mpr rfl
  show entryRecLt (prod2 (unitClosure 0 1) (nsingle (.face [1])))
    ⟨zeros j ++ [1], hj⟩ ⟨zeros k ++ [1], hk⟩
  rw [entryRecLt_prod2_iff (unitClosure 0 1) (nsingle (.face [1])) rfl,
    inSeamBlock_headPieces j hj hpj hface, inSeamBlock_headPieces k hk hpk hface]
  refine Or.inl (unitClosure_entryRank_lt_of_length_lt ?_)
  show (zeros j).length < (zeros k).length
  rw [zeros_length, zeros_length]
  exact hjk

/-- Surviving heads compare by run length. -/
theorem inSeamBlock_headRank_lt_iff {j k : ℕ}
    (hj : denotes inSeamBlock (zeros j ++ [1]))
    (hk : denotes inSeamBlock (zeros k ++ [1])) :
    entryRank inSeamBlock ⟨zeros j ++ [1], hj⟩
      < entryRank inSeamBlock ⟨zeros k ++ [1], hk⟩ ↔ j < k := by
  rcases Nat.lt_trichotomy j k with h | rfl | h
  · exact iff_of_true (inSeamBlock_headRank_lt h hj hk) h
  · exact iff_of_false (lt_irrefl _) (lt_irrefl _)
  · exact iff_of_false (lt_asymm (inSeamBlock_headRank_lt h hk hj)) (by omega)

/-- Surviving heads with equal rank share the run length: the head block
index is injective. -/
theorem inSeamBlock_headRank_eq_iff {j k : ℕ}
    (hj : denotes inSeamBlock (zeros j ++ [1]))
    (hk : denotes inSeamBlock (zeros k ++ [1])) :
    entryRank inSeamBlock ⟨zeros j ++ [1], hj⟩
      = entryRank inSeamBlock ⟨zeros k ++ [1], hk⟩ ↔ j = k := by
  constructor
  · intro h
    have hval := congrArg Subtype.val
      (entryRank_injective inSeamBlock inSeamBlock_nSubfree h)
    have hlen := congrArg List.length hval
    simp only [List.length_append, List.length_cons, List.length_nil,
      zeros_length] at hlen
    omega
  · rintro rfl
    rfl

/-- The in-range seam row recurses as run-length-many surviving head blocks
over the tail closure's own recursive order: collision ownership erases
every split but the first-marker one, and what remains is `ℕ` lex a full
omega block -- phase F's "`b`-free blocks embed a full ω·ω", generated. -/
noncomputable def inSeamRowRecIso :
    entryRecLt (prod2 inSeamBlock (unitClosure 0 1))
      ≃r Prod.Lex ((· < ·) : ℕ → ℕ → Prop) (entryRecLt (unitClosure 0 1)) where
  toEquiv := Equiv.ofBijective (fun e =>
    ((seamCut e.1).1, ⟨(seamCut e.1).2, inSeamRow_tail_denotes e⟩)) (by
    constructor
    · intro x y hxy
      simp only [Prod.mk.injEq, Subtype.mk.injEq] at hxy
      apply Subtype.ext
      rw [inSeamRow_cons x, inSeamRow_cons y, hxy.1, hxy.2]
    · rintro ⟨k, ⟨v, hv⟩⟩
      have hd : denotes (prod2 inSeamBlock (unitClosure 0 1)) (zeros k ++ 1 :: v) := by
        refine (inSeamRow_denotes_iff _).mpr
          ⟨List.mem_append_right _ List.mem_cons_self, ?_⟩
        intro c hc
        rcases List.mem_append.mp hc with h | h
        · exact zeros_bounded k c h
        · rcases List.mem_cons.mp h with rfl | h
          · exact le_refl 1
          · exact (unitClosure01_denotes v).mp hv c h
      refine ⟨⟨zeros k ++ 1 :: v, hd⟩, ?_⟩
      have hcut : seamCut (zeros k ++ 1 :: v) = (k, v) := by
        rw [seamCut_eq (one_not_mem_zeros k), zeros_length]
      refine Prod.ext ?_ (Subtype.ext ?_)
      · show (seamCut (zeros k ++ 1 :: v)).1 = k
        rw [hcut]
      · show (seamCut (zeros k ++ 1 :: v)).2 = v
        rw [hcut])
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply, Prod.lex_def]
    rw [entryRecLt_prod2_iff inSeamBlock (unitClosure 0 1) (unitClosure_nSubfree 0 1) x y]
    have hhx : (prod2RecPieces inSeamBlock (unitClosure 0 1) x).1
        = ⟨zeros (seamCut x.1).1 ++ [1], inSeamRow_head_denotes x⟩ :=
      congrArg Prod.fst (inSeamRow_survivor x)
    have hhy : (prod2RecPieces inSeamBlock (unitClosure 0 1) y).1
        = ⟨zeros (seamCut y.1).1 ++ [1], inSeamRow_head_denotes y⟩ :=
      congrArg Prod.fst (inSeamRow_survivor y)
    have htx : (prod2RecPieces inSeamBlock (unitClosure 0 1) x).2
        = ⟨(seamCut x.1).2, inSeamRow_tail_denotes x⟩ :=
      congrArg Prod.snd (inSeamRow_survivor x)
    have hty : (prod2RecPieces inSeamBlock (unitClosure 0 1) y).2
        = ⟨(seamCut y.1).2, inSeamRow_tail_denotes y⟩ :=
      congrArg Prod.snd (inSeamRow_survivor y)
    rw [hhx, hhy, htx, hty,
      inSeamBlock_headRank_lt_iff (inSeamRow_head_denotes x) (inSeamRow_head_denotes y),
      inSeamBlock_headRank_eq_iff (inSeamRow_head_denotes x) (inSeamRow_head_denotes y)]
    exact Iff.rfl

/-- Headline: the in-range seam row keeps omega^2 on the recursive order --
the doc's `{b}{a..}{b}{a..}` with the seam character genuinely inside the
range, where "the seams collide (`babba` is both `b|a|b|ba` and `b|ab|b|a`),
yet every pair with a `b`-free first segment is its own least split --
infinitely many full omega-blocks survive, cofinally, so omega^2 stands."

Unlike `seamRow_entryRecType` the splits collide (`inSeamRow_splits_collide`),
so the type cannot come from the unique-split product law: the recursion's
own split choice drops every claimant but the first-marker one
(`inSeamRow_someSplit`), the surviving marker-free heads `0^k` stand
cofinally (`inSeamRow_survivor`), each with the tail closure's full omega
block -- phase F's `seam_collision_survives`, landed on a real term. -/
theorem inSeamRow_entryRecType :
    entryRecType (prod2 inSeamBlock (unitClosure 0 1)) = ω ^ (2 : Ordinal) := by
  have hsub : nSubfree (prod2 inSeamBlock (unitClosure 0 1)) = true := by
    simp [prod2, nsingle, nSubfree, mSubfree, fSubfree, inSeamBlock_nSubfree,
      unitClosure_nSubfree]
  haveI := entryRecLt_isWellOrder (prod2 inSeamBlock (unitClosure 0 1)) hsub
  haveI := entryRecLt_isWellOrder (unitClosure 0 1) (unitClosure_nSubfree 0 1)
  rw [entryRecType_def (prod2 inSeamBlock (unitClosure 0 1)) hsub,
    Ordinal.type_eq.mpr ⟨inSeamRowRecIso⟩, type_prod_lex,
    ← entryRecType_def (unitClosure 0 1) (unitClosure_nSubfree 0 1),
    unitClosure_entryRecType 0 1 (by omega), type_nat_lt,
    show (2 : Ordinal) = 1 + 1 by norm_num, opow_add, opow_one]

end L1
