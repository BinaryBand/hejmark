/- L1 bridge: the body-recursive within-body order (design in
`RecOrder.design.md`).

This module replaces the sanctioned within-body approximation -- `entrySpellLt`
orders a node's entries by raw shortlex -- with an order that recurses into each
constructor's own structure. It is the upstream primitive the rest of
`L1/Bridge/` is framed onto, so it lands additively: the definitions and their
well-order theory go here first, and `entriesType`/`prodLt`/`unionLt`/`Rows`
migrate onto it one module at a time, every intermediate build green.

This first increment is the reusable core of the design's central move. The
existing bridge files prove `IsWellOrder` by embedding into a `Prod.Lex` of
known well orders; for a recursive order that target is itself recursive and
dependent on which sub-body owns an entry, which is awkward to write. Instead an
order is presented as a rank into the single, non-dependent type `Ordinal`:
`rankLt rank a b := rank a < rank b`. Well-foundedness and transitivity are then
free (they are `<` on `Ordinal`, pulled back), so the entire novelty of the
well-order proof collapses to one obligation -- the rank is injective. The
recursive `entryRank` and its injectivity are the next increment. -/
import L1.Bridge.Entries

namespace L1

open Ordinal

/- ---------------------------------------------------------------- -/
/- Rank-into-ordinal orders: well-founded and transitive for free,  -/
/- a well order exactly when the rank is injective.                 -/
/- ---------------------------------------------------------------- -/

namespace RecOrder

variable {α : Type*} (rank : α → Ordinal)

/-- The order a rank induces: compare ranks in the ordinals. -/
def rankLt (a b : α) : Prop := rank a < rank b

/-- Pulled back from a well-founded relation, so well-founded with no
hypotheses on the rank. -/
instance isWellFounded : IsWellFounded α (rankLt rank) :=
  ⟨InvImage.wf rank wellFounded_lt⟩

/-- Pulled back from `<` on `Ordinal`, so transitive with no hypotheses. -/
instance isTrans : IsTrans α (rankLt rank) :=
  ⟨fun _ _ _ h₁ h₂ => lt_trans h₁ h₂⟩

/-- An injective rank is a relation embedding of the induced order into `<` on
the ordinals (the relation condition is definitional). -/
def rankEmb (hinj : Function.Injective rank) :
    rankLt rank ↪r ((· < ·) : Ordinal → Ordinal → Prop) :=
  ⟨⟨rank, hinj⟩, Iff.rfl⟩

/-- The one obligation: an injective rank makes the induced order a well order --
`<` on `Ordinal` is one, and the embedding transports it back. -/
theorem isWellOrder_of_injective (hinj : Function.Injective rank) :
    IsWellOrder α (rankLt rank) :=
  (rankEmb rank hinj).isWellOrder

/- ---------------------------------------------------------------- -/
/- Every well order is already a rank order: its own `typein`.       -/
/- This is the base of the recursion -- a leaf node's entries carry  -/
/- no reordering, so their rank is exactly the ordinal position in   -/
/- the shortlex (spelling) order, `typein (entrySpellLt n)`. The two -/
/- facts below say that recovers the original order on the nose and  -/
/- is injective, so every order the bridge already builds            -/
/- (`entrySpellLt`, `entryLt`, `prodLt`, `unionLt`) is an instance of -/
/- the rank framework, not a competitor to it.                       -/
/- ---------------------------------------------------------------- -/

section Typein

variable {r : α → α → Prop} [IsWellOrder α r]

/-- `typein` is injective on a well order: it is an order iso onto an initial
segment, so distinct elements land at distinct ordinal positions. -/
theorem typein_injective : Function.Injective (Ordinal.typein r) :=
  Ordinal.typein_injective r

/-- The rank order induced by `typein r` is `r` itself -- `typein` reflects and
preserves the order, so nothing is reordered by passing through the ordinals. -/
theorem rankLt_typein_eq : rankLt (Ordinal.typein r) = r := by
  ext a b
  exact Ordinal.typein_lt_typein r

end Typein

end RecOrder

end L1
