/- L1 bridge: binary products on real syntax -- positional order and
collision ownership of faces.

`docs/foundation/L1.md` (Positional value) orders a product's entries by
mixed-radix positional value, most significant factor first, and settles
every collision by one rule: "a spelling is claimed by the least
`<value, face>` address that spells it ... and every later claimant drops
it". `L1/Order/Collision.lean` proves that ownership rule well-defined over
an abstract address space and `L1/Order/Collapse.lean` computes what
survives it over abstract pairs; this file lands both on the real syntax:
the addresses are the actual cuts `s = p ++ q` that `Semantics.lean`'s
`fsplit` ranges over to denote a product, positional order is the
lexicographic spelling order on those cuts (prefix most significant), and
an entry is owned by its least cut.

The load-bearing fact is that a `prod` wrapper never binds: `freeAmpb`
detects only a literal `&` factor and never recurses into a brace factor
(`Syntax.lean`'s binder-detection comment -- the fold's own braces are the
innermost binder site), so `prod2 a b` is a non-binder even when a factor
(e.g. `unitClosure`) is itself a binder, and the denotation inversion
`prod2_denotes_iff` is unconditional -- `fsplit` hands each factor exactly
its own `denotes`.

- `prod2_collision_settled`: the collision rule settles on real product
  syntax -- every denoted spelling has a unique least split,
  `collision_settled`'s content with real cuts for addresses.
- `prodLt`: the entry order -- compare owning splits positionally.
- `prodLt_type_of_unique_splits`: with unique splits the enumeration is the
  ordinal product of the factor enumerations, most significant factor on
  the left of the syntax and the right of the `*` --
  `positional_value_type`'s content read off the real term. The transfinite
  rows built on this live in `L1/Bridge/Rows.lean`. -/
import L1.Bridge.Entries

namespace L1

open Ordinal

/- ---------------------------------------------------------------- -/
/- The term shape and its unconditional inversion.                   -/
/- ---------------------------------------------------------------- -/

/-- Binary product on real syntax: one `prod` member with two brace
factors. -/
def prod2 (a b : Node) : Node := nsingle (.prod (.node a (.node b .nil)))

/-- A `prod` wrapper never binds: a free `&` is only ever a literal `&`
factor, and a brace factor keeps its binders to itself. -/
theorem prod2_bindsb (a b : Node) : bindsb (prod2 a b) = false := rfl

/-- The load-bearing inversion, unconditional -- binder factors included: a
binary product wears exactly the concatenations of its factors' spellings. -/
theorem prod2_denotes_iff (a b : Node) (s : Spelling) :
    denotes (prod2 a b) s ↔ ∃ p q, s = p ++ q ∧ denotes a p ∧ denotes b q := by
  have h : denotes (prod2 a b) s
      ↔ fsplit (.node a (.node b .nil)) (fun _ => False) s := by
    show ndenote (prod2 a b) (fun _ => False) s ↔ _
    rw [ndenote_nonbinder _ _ _ (prod2_bindsb a b)]
    show walk (nsingle (.prod (.node a (.node b .nil)))) _ False s ↔ _
    rw [walk_single_prod, false_or]
  rw [h, fsplit_fnode]
  constructor
  · rintro ⟨p, q, rfl, hp, hq⟩
    rw [fsplit_fnode] at hq
    obtain ⟨p', q', rfl, hq', hnil⟩ := hq
    rw [fsplit_fnil] at hnil
    subst hnil
    exact ⟨p, p', by rw [List.append_nil], hp, hq'⟩
  · rintro ⟨p, q, rfl, hp, hq⟩
    refine ⟨p, q, rfl, hp, ?_⟩
    rw [fsplit_fnode]
    exact ⟨q, [], (List.append_nil q).symm, hq, by rw [fsplit_fnil]⟩

/- ---------------------------------------------------------------- -/
/- Split addresses and their positional order.                       -/
/- ---------------------------------------------------------------- -/

/-- Positional order on split addresses: lexicographic on the pieces,
prefix most significant -- the `<value, value>` reading of the doc's mixed
radix, with spelling order for value order. -/
abbrev splitLt : Spelling × Spelling → Spelling × Spelling → Prop :=
  Prod.Lex (List.Shortlex ((· < ·) : Code → Code → Prop))
    (List.Shortlex ((· < ·) : Code → Code → Prop))

/-- The splits of `s` across factors `a`, `b`: the real addresses `fsplit`
ranges over. -/
def IsSplit (a b : Node) (s : Spelling) (pq : Spelling × Spelling) : Prop :=
  s = pq.1 ++ pq.2 ∧ denotes a pq.1 ∧ denotes b pq.2

theorem isSplit_of_denotes {a b : Node} {s : Spelling}
    (h : denotes (prod2 a b) s) : ∃ pq, IsSplit a b s pq := by
  obtain ⟨p, q, rfl, hp, hq⟩ := (prod2_denotes_iff a b _).mp h
  exact ⟨(p, q), rfl, hp, hq⟩

/- ---------------------------------------------------------------- -/
/- Collision ownership: the least split claims the spelling.         -/
/- ---------------------------------------------------------------- -/

/-- Collision ownership of faces on real syntax: an entry is owned by the
least split address that spells it. -/
noncomputable def leastSplit (a b : Node) (e : Entries (prod2 a b)) :
    Spelling × Spelling :=
  (IsWellFounded.wf (r := splitLt)).min {pq | IsSplit a b e.1 pq}
    (isSplit_of_denotes e.2)

theorem leastSplit_isSplit (a b : Node) (e : Entries (prod2 a b)) :
    IsSplit a b e.1 (leastSplit a b e) :=
  WellFounded.min_mem (IsWellFounded.wf (r := splitLt))
    {pq | IsSplit a b e.1 pq} (isSplit_of_denotes e.2)

theorem leastSplit_not_lt (a b : Node) (e : Entries (prod2 a b))
    {pq : Spelling × Spelling} (h : IsSplit a b e.1 pq) :
    ¬ splitLt pq (leastSplit a b e) :=
  WellFounded.not_lt_min (IsWellFounded.wf (r := splitLt))
    {pq | IsSplit a b e.1 pq} h

/-- Pin the owner: a split that every other split equals-or-follows is the
least split. Every concrete row computes its owner through this. -/
theorem leastSplit_eq (a b : Node) (e : Entries (prod2 a b))
    {pq : Spelling × Spelling} (hmem : IsSplit a b e.1 pq)
    (hleast : ∀ pq', IsSplit a b e.1 pq' → pq' = pq ∨ splitLt pq pq') :
    leastSplit a b e = pq := by
  rcases hleast _ (leastSplit_isSplit a b e) with h | h
  · exact h
  · exact absurd h (leastSplit_not_lt a b e hmem)

/-- Headline: the collision rule settles on real product syntax -- every
denoted spelling of a binary product is claimed by a unique least split
address. `collision_settled` proved the rule well-defined over abstract
`<value, face>` addresses; here the addresses are the real cuts `fsplit`
ranges over. -/
theorem prod2_collision_settled (a b : Node) (s : Spelling)
    (h : denotes (prod2 a b) s) :
    ∃! pq, IsSplit a b s pq
      ∧ ∀ pq', IsSplit a b s pq' → pq' = pq ∨ splitLt pq pq' := by
  refine ⟨leastSplit a b ⟨s, h⟩, ⟨leastSplit_isSplit a b ⟨s, h⟩, ?_⟩, ?_⟩
  · intro pq' h'
    rcases trichotomous_of splitLt pq' (leastSplit a b ⟨s, h⟩) with hlt | heq | hgt
    · exact absurd hlt (leastSplit_not_lt a b ⟨s, h⟩ h')
    · exact Or.inl heq
    · exact Or.inr hgt
  · rintro pq ⟨hmem, hleast⟩
    exact (leastSplit_eq a b ⟨s, h⟩ hmem hleast).symm

/- ---------------------------------------------------------------- -/
/- The entry order and its type under unique splits.                 -/
/- ---------------------------------------------------------------- -/

/-- The entry order on a binary product: compare owning splits positionally
-- positional order with collision ownership, on real syntax. -/
def prodLt (a b : Node) : Entries (prod2 a b) → Entries (prod2 a b) → Prop :=
  fun x y => splitLt (leastSplit a b x) (leastSplit a b y)

/-- Owning addresses embed the entry order into the positional order on all
addresses -- injective because the owning split reconstructs its entry. -/
noncomputable def prodAddrEmb (a b : Node) : prodLt a b ↪r splitLt :=
  ⟨⟨leastSplit a b, fun x y h => Subtype.ext (by
      rw [(leastSplit_isSplit a b x).1, (leastSplit_isSplit a b y).1, h])⟩,
    Iff.rfl⟩

instance (a b : Node) : IsWellOrder (Entries (prod2 a b)) (prodLt a b) :=
  (prodAddrEmb a b).isWellOrder

/-- With unique splits the owner map is an order isomorphism onto the lex
product of the factor entry orders. -/
noncomputable def prodSplitIso (a b : Node)
    (huniq : ∀ s pq pq', IsSplit a b s pq → IsSplit a b s pq' → pq = pq') :
    prodLt a b ≃r Prod.Lex (entrySpellLt a) (entrySpellLt b) where
  toEquiv := Equiv.ofBijective (fun e =>
    (⟨(leastSplit a b e).1, (leastSplit_isSplit a b e).2.1⟩,
     ⟨(leastSplit a b e).2, (leastSplit_isSplit a b e).2.2⟩)) (by
    constructor
    · intro x y hxy
      simp only [Prod.mk.injEq, Subtype.mk.injEq] at hxy
      apply Subtype.ext
      rw [(leastSplit_isSplit a b x).1, (leastSplit_isSplit a b y).1,
        hxy.1, hxy.2]
    · rintro ⟨⟨p, hp⟩, ⟨q, hq⟩⟩
      have hd : denotes (prod2 a b) (p ++ q) :=
        (prod2_denotes_iff a b _).mpr ⟨p, q, rfl, hp, hq⟩
      have hmem : IsSplit a b (p ++ q) (p, q) := ⟨rfl, hp, hq⟩
      have hls : leastSplit a b ⟨p ++ q, hd⟩ = (p, q) :=
        leastSplit_eq a b ⟨p ++ q, hd⟩ hmem
          (fun pq' h' => Or.inl (huniq _ _ _ h' hmem))
      exact ⟨⟨p ++ q, hd⟩, Prod.ext (Subtype.ext (congrArg Prod.fst hls))
        (Subtype.ext (congrArg Prod.snd hls))⟩)
  map_rel_iff' := by
    intro x y
    simp only [Equiv.ofBijective_apply, prodLt, entrySpellLt, Prod.lex_def,
      subrel_val, Subtype.mk.injEq]

/-- Headline: positional value on real syntax -- with unique splits the
entry order is the ordinal product of the factor enumerations, the most
significant factor on the left of the syntax and the right of the `*`. -/
theorem prodLt_type_of_unique_splits (a b : Node)
    (huniq : ∀ s pq pq', IsSplit a b s pq → IsSplit a b s pq' → pq = pq') :
    Ordinal.type (prodLt a b) = entriesType b * entriesType a := by
  rw [Ordinal.type_eq.mpr ⟨prodSplitIso a b huniq⟩, type_prod_lex]
  rfl

end L1
