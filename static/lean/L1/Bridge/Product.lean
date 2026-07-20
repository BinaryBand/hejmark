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

The entry order itself and its ordinal type now live in `RecOrder.lean`'s
body-recursive order (`entryRecType_prod2`, the positional product law); the
split machinery here (`IsSplit`, `leastSplit`, `prod2_collision_settled`)
still supplies the collision-ownership facts that law and the transfinite
rows in `L1/Bridge/Rows.lean` consume. -/
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

end L1
