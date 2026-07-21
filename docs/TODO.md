# TODO: deferred increments

<!-- cspell:words uncomputable hejmark -->

Priority and rationale for deferred work. This file only ranks what remains and says why; two ledgers stay authoritative -- the **"What this does not prove"** section of `static/lean/README.md` for the mechanization, and `docs/foundation/ROADMAP.md` for the layers. When an item lands, update its ledger first.

## Do next

Nothing is queued. Every item below waits on something that does not yet exist -- a row, a layer, or a use that forces the design.

## Language surface

### 1. Expressive render layer

**The gap.** A cast by value is uncomputable today. `@lo..hi` cuts one head's value line and names its bounds in that head's own numerals, so writing a bound value under a *second* universe -- decimal to hex, a unary run's length as a decimal numeral -- is value-indexing across two radixes, which no expression computes and no register spells (`docs/foundation/L1_5.md`, Worked derivations).

**The groundwork, landed.** A render that carries a computed value needs somewhere for that value to land, and the natural bound is the target universe's own entry count -- its **ceiling** -- so a value that overflows folds back modulo the ceiling and always names an entry that exists. `hejmark/core/floor/ceiling.py` prices it: `cardinality` computes the count structurally, never streaming an entry, so an astronomically wide field costs nothing to price. It is exact over disjoint faces and ranges and products of those, and returns `None` -- "no known ceiling", never a wrong one -- wherever the collision rule might drop an entry (an overlap, a subtraction) or a member is unbounded (a final segment, a closure). Nothing consumes it yet, by intent.

**Why it is deferred.** It is a denotational addition, so it grows L1.5 rather than the execution contract -- and a new register faces the scrutiny a new axiom does, since L1.5's finish line is measured by the inventory staying four tokens. The design is not forced yet; the first script that genuinely wants it should settle:

- which token spells the render, and whether it is a register at all or a template form;
- what a `None` ceiling refuses -- an infinite target carries no modulus, so the render is a diagnostic there, which puts it on the finite-execution contract's shelf (`docs/foundation/L2.md`);
- whether the wrap is a modulo or a saturating cut, and whether what is rendered is the entry's own value or something computed from it.

## Lean mechanization

Deferred until needed -- each item waits on a row or a layer that does not yet exist. The last item with a hard case unmechanized on real syntax, **in-range-seam survivors**, landed as `inSeamRow_entryRecType` in `L1/Bridge/Rows.lean`: the seam row `{b}{a..}{b}{a..}` with the marker drawn from inside the closure range, where the splits genuinely collide (`inSeamRow_splits_collide`) yet the recursion's own least-split choice keeps the marker-free heads (`inSeamRow_someSplit`, `inSeamRow_survivor`) and $\omega^2$ survives -- phase F's abstract `seam_collision_survives`, now on a real term.

### 1. N-ary `Factors` positional machinery

No n-ary analogue of `entryRecType_prod2` reading a whole factor list as one mixed-radix positional order (`fRank` is n-ary; the type law is binary-only). Pure generalization -- the abstract n-ary theory already exists in `L1/Order/Positional.lean` and every current row needs only the binary form. Do it the day a row needs three factors.

### 2. Converse half of the admission test

Every closure-free universe has a regular face set. Needs a DFA / symbolic automaton construction for shortlex windows over the infinite code space -- the heaviest lift, for the least payoff: the direction that guards the spec (closure's witness `{ab, {a}&{b}}` is not regular, so closure cannot be compressed away) is already proved in `L1/Membership/Admission.lean`. No code path relies on the converse.

### 3. Face axis on real syntax

The ordinal-level face-vs-entry distinction (`{{{},0}}{0..9}` and kin) is not mechanized over real syntax; the north-star parse gate only accepts the rows. Guards doc claims only: the Python core is membership-only (`Match` carries spans and faces, no values), so there is no executable behavior for this to catch. Becomes interesting only if a future layer computes with face indices.
