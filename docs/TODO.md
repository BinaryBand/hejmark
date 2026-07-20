# TODO: deferred Lean increments

Priority and rationale for the deferred items in the L1 mechanization. The authoritative ledger is the **"What this does not prove"** section of `static/lean/README.md` -- when an item lands, update that section first; this file only ranks what remains and says why.

## Do next

Nothing is queued. The three items below are all "deferred until needed" by their own rationale -- each waits on a row or a layer that does not yet exist. The last item with a hard case unmechanized on real syntax, **in-range-seam survivors**, landed as `inSeamRow_entryRecType` in `L1/Bridge/Rows.lean`: the seam row `{b}{a..}{b}{a..}` with the marker drawn from inside the closure range, where the splits genuinely collide (`inSeamRow_splits_collide`) yet the recursion's own least-split choice keeps the marker-free heads (`inSeamRow_someSplit`, `inSeamRow_survivor`) and $\omega^2$ survives -- phase F's abstract `seam_collision_survives`, now on a real term.

## Deferred until needed

### 1. N-ary `Factors` positional machinery

No n-ary analogue of `entryRecType_prod2` reading a whole factor list as one mixed-radix positional order (`fRank` is n-ary; the type law is binary-only). Pure generalization -- the abstract n-ary theory already exists in `L1/Order/Positional.lean` and every current row needs only the binary form. Do it the day a row needs three factors.

### 2. Converse half of the admission test

Every closure-free universe has a regular face set. Needs a DFA / symbolic automaton construction for shortlex windows over the infinite code space -- the heaviest lift, for the least payoff: the direction that guards the spec (closure's witness `{ab, {a}&{b}}` is not regular, so closure cannot be compressed away) is already proved in `L1/Membership/Admission.lean`. No code path relies on the converse.

### 3. Face axis on real syntax

The ordinal-level face-vs-entry distinction (`{{{},0}}{0..9}` and kin) is not mechanized over real syntax; the north-star parse gate only accepts the rows. Guards doc claims only: the Python core is membership-only (`Match` carries spans and faces, no values), so there is no executable behavior for this to catch. Becomes interesting only if a future layer computes with face indices.
