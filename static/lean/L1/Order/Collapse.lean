/- L1 order axis, phase F: collision alone does not decide the type.

`docs/foundation/L1.md` ("Bounded transfinitude"): "Collision alone does not decide the type: each
drop keeps the least-valued split, and the surviving least splits do. In `{b}{a..}{b}{a..}` the
seams collide ... yet every pair with a `b`-free first segment is its own least split -- infinitely
many full ω-blocks survive, cofinally, so ω² stands. In `{a..}{a..}` the least split pins the
prefix, only finitely many blocks survive, and the type collapses to ω·k, k finite."

Over the finite alphabet of `L1/Order/Order.lean` (`FCode m = Fin (m+1)`), a product entry of two
final-segment factors is a pair of nonempty spellings ordered lexicographically by `(value, value)`
(the positional-value order; value order is shortlex order by `valueRelIso`). Two pairs collide
when they concatenate to the same spelling, and the collision rule keeps the lex-least pair
(`L1/Order/Collision.lean` is where least-claimant ownership itself is proved well-defined; here we
compute what the survivors' order type is).

- `{a..}{a..}` (`splitSurvives_iff`, `cofinite_collision_collapses`): a pair survives iff its
  prefix is a *singleton* -- any longer prefix is beaten by the same spelling's shorter split. So
  exactly `m + 1` blocks survive, one per code point, and the type collapses to `ω * (m+1)`:
  the doc's `ω · k` with `k` the (finite) alphabet size.
- `{b}{a..}{b}{a..}` (`bfree_survives`, `seam_collision_survives`): a pair whose first segment
  avoids the seam character `b` is its own least split -- a shorter prefix would place `b` inside
  the `b`-free segment, and a longer one is lex-greater. Those pairs form full ω-blocks cofinally,
  so the survivor order embeds ω·ω and sits inside the pre-collision ω·ω: the type stands at
  `ω * ω` (the doc's ω²).

Like the other order-axis phases this is an abstract mechanization over `L1/Order/Order.lean`'s finite
alphabet, not an enumeration of the real syntax. -/
import L1.Order.Order

namespace L1

open Ordinal

variable (m : Nat)

/-- Nonempty spellings: the entries of a final-segment factor `{a..}`. -/
abbrev NESp := {l : FSpelling m // l ≠ []}

/-- The factor order on nonempty spellings: shortlex, restricted. -/
abbrev neLt : NESp m → NESp m → Prop := Subrel (fshortlex m) (fun l => l ≠ [])

/-- The positional order on product pairs: lexicographic, left factor most significant -- exactly
the `<value, value>` reading, since value order is shortlex order (`valueRelIso`). -/
abbrev pairLt : NESp m × NESp m → NESp m × NESp m → Prop := Prod.Lex (neLt m) (neLt m)

/- ---------------------------------------------------------------- -/
/- Shortlex facts read through `value` (`fshortlex_iff_value_lt`      -/
/- lives with `valueRelIso` in `Order.lean`).                        -/
/- ---------------------------------------------------------------- -/

theorem value_nil : value m ([] : FSpelling m) = 0 := rfl

theorem one_le_value {l : FSpelling m} (h : l ≠ []) : 1 ≤ value m l := by
  have h1 : 0 < l.length := List.length_pos_of_ne_nil h
  have h2 := lenOffset_ge m l.length
  simp only [value]
  omega

theorem singleton_fshortlex_iff {c c' : FCode m} : fshortlex m [c] [c'] ↔ c < c' := by
  constructor
  · intro h
    rcases List.shortlex_def.mp h with hlt | ⟨_, hlex⟩
    · simp at hlt
    · cases hlex with
      | rel h => exact h
      | cons h => cases h
  · intro h
    exact List.shortlex_def.mpr (Or.inr ⟨rfl, List.Lex.rel h⟩)

theorem shortlex_of_length_lt {l1 l2 : FSpelling m} (h : l1.length < l2.length) :
    fshortlex m l1 l2 :=
  List.shortlex_def.mpr (Or.inl h)

/-- The nonempty spellings still have order type ω: `value - 1` is the order isomorphism onto
`(ℕ, <)`. -/
noncomputable def nonemptyValueIso : (neLt m) ≃r ((· < ·) : ℕ → ℕ → Prop) where
  toEquiv := Equiv.ofBijective (fun l => value m l.1 - 1) (by
    constructor
    · rintro ⟨l1, h1⟩ ⟨l2, h2⟩ heq
      simp only at heq
      have hv1 := one_le_value m h1
      have hv2 := one_le_value m h2
      have : value m l1 = value m l2 := by omega
      exact Subtype.ext (value_injective m this)
    · intro n
      obtain ⟨l, hl⟩ := value_surjective m (n + 1)
      have hne : l ≠ [] := by
        intro h
        subst h
        rw [value_nil] at hl
        omega
      exact ⟨⟨l, hne⟩, by simp only; omega⟩)
  map_rel_iff' := by
    rintro ⟨l1, h1⟩ ⟨l2, h2⟩
    simp only [Equiv.ofBijective_apply, subrel_val]
    have hv1 := one_le_value m h1
    have hv2 := one_le_value m h2
    rw [fshortlex_iff_value_lt]
    omega

theorem neLt_type : Ordinal.type (neLt m) = ω := by
  rw [Ordinal.type_eq.mpr ⟨nonemptyValueIso m⟩]
  exact type_nat_lt

/-- The pre-collision pair space has type ω·ω: ω-many full ω-blocks, prefix-major. -/
theorem pairLt_type : Ordinal.type (pairLt m) = ω * ω := by
  rw [type_prod_lex, neLt_type]

/- ---------------------------------------------------------------- -/
/- `{a..}{a..}`: cofinite factors collide, the type collapses.       -/
/- ---------------------------------------------------------------- -/

/-- What a pair spells: the concatenation. Two pairs collide when they spell the same thing. -/
def spelled (x : NESp m × NESp m) : FSpelling m := x.1.1 ++ x.2.1

/-- The survivor predicate for `{a..}{a..}`: a pair keeps its spelling iff it is the lex-least
claimant -- the collision rule of `L1/Order/Collision.lean`, specialized to this product. -/
def SplitSurvives (x : NESp m × NESp m) : Prop :=
  ∀ y, spelled m y = spelled m x → y = x ∨ pairLt m x y

/-- The least split pins the prefix: a pair survives iff its prefix is a singleton. Any longer
prefix loses its spelling to the split one character in, whose prefix value is strictly smaller. -/
theorem splitSurvives_iff (x : NESp m × NESp m) :
    SplitSurvives m x ↔ x.1.1.length = 1 := by
  obtain ⟨⟨p, hp⟩, ⟨q, hq⟩⟩ := x
  constructor
  · intro hs
    by_contra hne
    simp only at hne
    obtain ⟨c, t, rfl⟩ : ∃ c t, p = c :: t := by
      cases p with
      | nil => exact absurd rfl hp
      | cons c t => exact ⟨c, t, rfl⟩
    have ht : t ≠ [] := by
      intro h
      subst h
      simp at hne
    have htq : t ++ q ≠ [] :=
      List.ne_nil_of_length_pos (by
        have := List.length_pos_of_ne_nil ht
        simp only [List.length_append]
        omega)
    have hclaim : spelled m (⟨[c], by simp⟩, ⟨t ++ q, htq⟩) = spelled m (⟨c :: t, hp⟩, ⟨q, hq⟩) := by
      simp [spelled]
    rcases hs _ hclaim with heq | hlt
    · have hlen := congrArg (fun z => z.1.1.length) heq
      simp only [List.length_cons, List.length_nil] at hlen
      have := List.length_pos_of_ne_nil ht
      omega
    · have hshort : fshortlex m [c] (c :: t) :=
        shortlex_of_length_lt m (by
          have := List.length_pos_of_ne_nil ht
          simp only [List.length_cons, List.length_nil]
          omega)
      rcases Prod.lex_def.mp hlt with hleft | ⟨heq1, _⟩
      · exact absurd (trans_of (fshortlex m) (hleft : fshortlex m (c :: t) [c]) hshort)
          (irrefl_of (fshortlex m) _)
      · have hlen := congrArg (fun z => z.1.length) heq1
        simp only [List.length_cons, List.length_nil] at hlen
        have := List.length_pos_of_ne_nil ht
        omega
  · intro hlen y hclaim
    obtain ⟨c, rfl⟩ : ∃ c, p = [c] := by
      cases p with
      | nil => exact absurd rfl hp
      | cons c t =>
          simp only [List.length_cons] at hlen
          have : t = [] := List.length_eq_zero_iff.mp (by omega)
          exact ⟨c, by rw [this]⟩
    obtain ⟨⟨p', hp'⟩, ⟨q', hq'⟩⟩ := y
    simp only [spelled, List.singleton_append] at hclaim
    obtain ⟨c', t', rfl⟩ : ∃ c' t', p' = c' :: t' := by
      cases p' with
      | nil => exact absurd rfl hp'
      | cons c' t' => exact ⟨c', t', rfl⟩
    cases t' with
    | nil =>
        simp only [List.cons_append, List.nil_append, List.cons.injEq] at hclaim
        left
        obtain ⟨rfl, rfl⟩ := hclaim
        rfl
    | cons d t'' =>
        right
        refine Prod.lex_def.mpr (Or.inl ?_)
        exact shortlex_of_length_lt m (by
          simp only [List.length_cons, List.length_nil]
          omega)

/-- Headline (`{a..}{a..}`): the survivors of the cofinite collision have order type exactly
`ω * (m + 1)` -- the doc's "the type collapses to ω·k, k finite", with `k` the alphabet size. Only
the `m + 1` singleton-prefix blocks survive, each still a full ω. -/
theorem cofinite_collision_collapses :
    Ordinal.type (Subrel (pairLt m) (SplitSurvives m)) = ω * ((m + 1 : ℕ) : Ordinal) := by
  apply le_antisymm
  · -- Embed the survivors into `Fin (m+1) ×ₗ ℕ`: prefix head, then suffix value.
    have femb : Subrel (pairLt m) (SplitSurvives m) ↪r
        Prod.Lex ((· < ·) : FCode m → FCode m → Prop) ((· < ·) : ℕ → ℕ → Prop) := by
      refine RelEmbedding.ofMonotone
        (fun x => (x.1.1.1.head x.1.1.2, value m x.1.2.1 - 1)) ?_
      rintro ⟨x, hx⟩ ⟨y, hy⟩ h
      have hxlen := (splitSurvives_iff m x).mp hx
      have hylen := (splitSurvives_iff m y).mp hy
      obtain ⟨cx, hcx⟩ : ∃ c, x.1.1 = [c] := List.length_eq_one_iff.mp hxlen
      obtain ⟨cy, hcy⟩ : ∃ c, y.1.1 = [c] := List.length_eq_one_iff.mp hylen
      have h' : pairLt m x y := h
      rcases Prod.lex_def.mp h' with hleft | ⟨heq1, hlt2⟩
      · refine Prod.lex_def.mpr (Or.inl ?_)
        have : fshortlex m [cx] [cy] := by
          rw [← hcx, ← hcy]
          exact hleft
        simp only [hcx, hcy, List.head_cons]
        exact (singleton_fshortlex_iff m).mp this
      · refine Prod.lex_def.mpr (Or.inr ⟨?_, ?_⟩)
        · have hval : x.1.1 = y.1.1 := congrArg Subtype.val heq1
          rw [hcx, hcy] at hval
          simp only [hcx, hcy, List.head_cons]
          exact (List.cons.injEq _ _ _ _).mp hval |>.1
        · have hv := (fshortlex_iff_value_lt m).mp (hlt2 : fshortlex m x.2.1 y.2.1)
          have h1 := one_le_value m x.2.2
          have h2 := one_le_value m y.2.2
          show value m x.2.1 - 1 < value m y.2.1 - 1
          omega
    calc Ordinal.type (Subrel (pairLt m) (SplitSurvives m))
        ≤ Ordinal.type (Prod.Lex ((· < ·) : FCode m → FCode m → Prop)
            ((· < ·) : ℕ → ℕ → Prop)) := femb.ordinal_type_le
      _ = ω * ((m + 1 : ℕ) : Ordinal) := by
          rw [type_prod_lex]
          rw [show Ordinal.type ((· < ·) : ℕ → ℕ → Prop) = ω from type_nat_lt]
          rw [show Ordinal.type ((· < ·) : FCode m → FCode m → Prop)
            = ((m + 1 : ℕ) : Ordinal) from type_fin (m + 1)]
  · -- Embed `Fin (m+1) ×ₗ ℕ` into the survivors: singleton prefixes with arbitrary suffixes.
    have gemb : Prod.Lex ((· < ·) : FCode m → FCode m → Prop) ((· < ·) : ℕ → ℕ → Prop) ↪r
        Subrel (pairLt m) (SplitSurvives m) := by
      refine RelEmbedding.ofMonotone (fun cn =>
        ⟨(⟨[cn.1], by simp⟩,
          ⟨Classical.choose (value_surjective m (cn.2 + 1)), by
            intro h
            have := Classical.choose_spec (value_surjective m (cn.2 + 1))
            rw [h, value_nil] at this
            omega⟩),
          (splitSurvives_iff m _).mpr rfl⟩) ?_
      rintro ⟨c, n⟩ ⟨c', n'⟩ h
      rcases Prod.lex_def.mp h with hleft | ⟨heq1, hlt2⟩
      · exact Prod.lex_def.mpr (Or.inl ((singleton_fshortlex_iff m).mpr hleft))
      · refine Prod.lex_def.mpr (Or.inr ⟨?_, ?_⟩)
        · simp only at heq1
          exact Subtype.ext (by rw [heq1])
        · have hn := Classical.choose_spec (value_surjective m (n + 1))
          have hn' := Classical.choose_spec (value_surjective m (n' + 1))
          refine (fshortlex_iff_value_lt m).mpr ?_
          rw [hn, hn']
          omega
    calc ω * ((m + 1 : ℕ) : Ordinal)
        = Ordinal.type (Prod.Lex ((· < ·) : FCode m → FCode m → Prop)
            ((· < ·) : ℕ → ℕ → Prop)) := by
          rw [type_prod_lex]
          rw [show Ordinal.type ((· < ·) : ℕ → ℕ → Prop) = ω from type_nat_lt]
          rw [show Ordinal.type ((· < ·) : FCode m → FCode m → Prop)
            = ((m + 1 : ℕ) : Ordinal) from type_fin (m + 1)]
      _ ≤ Ordinal.type (Subrel (pairLt m) (SplitSurvives m)) := gemb.ordinal_type_le

/- ---------------------------------------------------------------- -/
/- `{b}{a..}{b}{a..}`: the seams collide, yet ω² stands.             -/
/- ---------------------------------------------------------------- -/

/-- What a seam pair spells (the constant leading `{b}` dropped): first segment, the seam
character, second segment. -/
def seamSpelled (b : FCode m) (x : NESp m × NESp m) : FSpelling m :=
  x.1.1 ++ b :: x.2.1

/-- The survivor predicate for the seam row. -/
def SeamSurvives (b : FCode m) (x : NESp m × NESp m) : Prop :=
  ∀ y, seamSpelled m b y = seamSpelled m b x → y = x ∨ pairLt m x y

/-- "Every pair with a `b`-free first segment is its own least split": a shorter prefix would put
the seam character inside the `b`-free segment, and a longer prefix is shortlex-greater. -/
theorem bfree_survives (b : FCode m) (x : NESp m × NESp m) (hbp : b ∉ x.1.1) :
    SeamSurvives m b x := by
  obtain ⟨⟨p, hp⟩, ⟨q, hq⟩⟩ := x
  rintro ⟨⟨p', hp'⟩, ⟨q', hq'⟩⟩ hclaim
  simp only [seamSpelled] at hclaim
  simp only at hbp
  rcases Nat.lt_trichotomy p'.length p.length with hlt | heq | hgt
  · -- A strictly shorter prefix forces `b` into `p`, contradicting `b`-freeness.
    exfalso
    have hpre1 : p' <+: (p' ++ b :: q') := List.prefix_append p' (b :: q')
    have hpre2 : p <+: (p ++ b :: q) := List.prefix_append p (b :: q)
    rw [hclaim] at hpre1
    have hpp : p' <+: p := List.prefix_of_prefix_length_le hpre1 hpre2 (Nat.le_of_lt hlt)
    obtain ⟨t, rfl⟩ := hpp
    have ht : t ≠ [] := by
      intro h
      subst h
      simp at hlt
    rw [List.append_assoc] at hclaim
    have htail : b :: q' = t ++ b :: q := List.append_cancel_left hclaim
    cases t with
    | nil => exact ht rfl
    | cons th tt =>
        simp only [List.cons_append, List.cons.injEq] at htail
        exact hbp (List.mem_append_right p' (htail.1 ▸ List.mem_cons_self))
  · -- Equal lengths: same prefix, same suffix -- it is the same pair.
    left
    obtain ⟨h1, h2⟩ := List.append_inj hclaim heq
    simp only [List.cons.injEq] at h2
    simp [h1, h2.2]
  · -- A strictly longer prefix is shortlex-greater: the pair drops to us, not us to it.
    right
    exact Prod.lex_def.mpr (Or.inl (shortlex_of_length_lt m hgt))

/-- Headline (`{b}{a..}{b}{a..}`): the seam survivors keep order type `ω * ω` -- the doc's "ω²
stands". The `b`-free blocks embed a full ω·ω from below, and the pre-collision pair space bounds it
from above. Stated over any second code point `c ≠ b`, i.e. any alphabet with at least two
characters. -/
theorem seam_collision_survives (b c : FCode m) (hcb : c ≠ b) :
    Ordinal.type (Subrel (pairLt m) (SeamSurvives m b)) = ω * ω := by
  apply le_antisymm
  · calc Ordinal.type (Subrel (pairLt m) (SeamSurvives m b))
        ≤ Ordinal.type (pairLt m) := (Subrel.relEmbedding _ _).ordinal_type_le
      _ = ω * ω := pairLt_type m
  · -- Embed ℕ ×ₗ ℕ via `b`-free replicated spellings `c^(i+1)`.
    have hrep : ∀ i : ℕ, (List.replicate (i + 1) c : FSpelling m) ≠ [] := by
      intro i h
      have := congrArg List.length h
      simp at this
    have hrepmem : ∀ i : ℕ, b ∉ (List.replicate (i + 1) c : FSpelling m) := by
      intro i hmem
      exact hcb (List.eq_of_mem_replicate hmem).symm
    have hreplt : ∀ {i j : ℕ}, i < j →
        fshortlex m (List.replicate (i + 1) c) (List.replicate (j + 1) c) := by
      intro i j hij
      exact shortlex_of_length_lt m (by simp; omega)
    have gemb : Prod.Lex ((· < ·) : ℕ → ℕ → Prop) ((· < ·) : ℕ → ℕ → Prop) ↪r
        Subrel (pairLt m) (SeamSurvives m b) := by
      refine RelEmbedding.ofMonotone (fun ij =>
        ⟨(⟨List.replicate (ij.1 + 1) c, hrep ij.1⟩, ⟨List.replicate (ij.2 + 1) c, hrep ij.2⟩),
          bfree_survives m b _ (hrepmem ij.1)⟩) ?_
      rintro ⟨i, j⟩ ⟨i', j'⟩ h
      rcases Prod.lex_def.mp h with hleft | ⟨heq1, hlt2⟩
      · exact Prod.lex_def.mpr (Or.inl (hreplt hleft))
      · refine Prod.lex_def.mpr (Or.inr ⟨?_, hreplt hlt2⟩)
        simp only at heq1
        exact Subtype.ext (by rw [heq1])
    calc ω * ω
        = Ordinal.type (Prod.Lex ((· < ·) : ℕ → ℕ → Prop) ((· < ·) : ℕ → ℕ → Prop)) := by
          rw [type_prod_lex]
          rw [show Ordinal.type ((· < ·) : ℕ → ℕ → Prop) = ω from type_nat_lt]
      _ ≤ Ordinal.type (Subrel (pairLt m) (SeamSurvives m b)) := gemb.ordinal_type_le

end L1
