# TODO: deferred Lean increments

Priority and rationale for the five deferred items in the L1 mechanization. The authoritative ledger is the **"What this does not prove"** section of `static/lean/README.md` -- when an item lands, update that section first; this file only ranks what remains and says why.

## Do next

### 1. Canonical numerals in shortlex (sub-range radix)

The doc's canonical-numerals theorem (`docs/foundation/L1.md`, "Canonical numerals"): value order agrees with spelling order on the canonical numerals of a code-point-ordered character radix. Proved only in fragments -- phase A's `fshortlex_iff_value_lt` (full spelling space, uniform radix) and `unitClosure_entryLt_iff` (the demotion row). The unproved piece is the leading-zero-free numerals of a *sub-range* head radix, i.e. the `{0, {1..9, &{0..9}}}` north-star shape itself, including the first-appearance half on the real stage ladder.

**Why first:** the only deferred item that underwrites shipped code, not just the doc. `core/surface/valueline.py`'s digit-walk, the `where` pipeline, and the sort north star's `padfree` measure all execute on this assumption -- the doc itself calls it "the read L1.5's `where` leans on". An off-by-one in the leading-digit story would surface here and nowhere else. Precedent says real-syntax order proofs find things (the \\omega\\cdot 4 correction to `{a..}{a..}` came from exactly this kind of landing).

### 2. In-range-seam survivors on real syntax

`seamRow_entryRecType` proves the seam row with the marker *outside* the closure range, so every spelling splits uniquely. The doc's harder claim -- seams collide, yet \\omega\\cdot k blocks summed cofinally still give \\omega^2 -- exists only as phase F's abstract `seam_collision_survives` (`L1/Order/Collapse.lean`), never landed on a real term.

**Why:** the last north-star ordinal row whose hard case isn't on real syntax, and it would exercise `someSplitP` under genuinely colliding splits -- the least-tested corner of `L1/Bridge/Split.lean`. Expect confirmation rather than a finding: even a k-shift inside the surviving blocks absorbs (\\omega\\cdot k blocks summed cofinally still give \\omega^2), so the headline is robust to the kind of surprise this machinery produces.

## Deferred until needed

### 3. N-ary `Factors` positional machinery

No n-ary analogue of `entryRecType_prod2` reading a whole factor list as one mixed-radix positional order (`fRank` is n-ary; the type law is binary-only). Pure generalization -- the abstract n-ary theory already exists in `L1/Order/Positional.lean` and every current row needs only the binary form. Do it the day a row needs three factors.

### 4. Converse half of the admission test

Every closure-free universe has a regular face set. Needs a DFA / symbolic automaton construction for shortlex windows over the infinite code space -- the heaviest lift of the five, for the least payoff: the direction that guards the spec (closure's witness `{ab, {a}&{b}}` is not regular, so closure cannot be compressed away) is already proved in `L1/Membership/Admission.lean`. No code path relies on the converse.

### 5. Face axis on real syntax

The ordinal-level face-vs-entry distinction (`{{{},0}}{0..9}` and kin) is not mechanized over real syntax; the north-star parse gate only accepts the rows. Guards doc claims only: the Python core is membership-only (`Match` carries spans and faces, no values), so there is no executable behavior for this to catch. Becomes interesting only if a future layer computes with face indices.
