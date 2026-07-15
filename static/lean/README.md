# Lean 4 scaffold (comparison track)

A parallel toolchain to `static/formal/` (Coq), for comparing workflow and tooling -- not a second mechanization of L1. It carries one ported theorem as a trial (see below); the rest of the membership axis stays in Coq until/unless a decision is made to migrate or fork it.

Build with `lake build` from this directory. Lean/Lake come from an `elan`-managed toolchain (pinned via `lean-toolchain`); the pytest gate in `tests/infrastructure/test_lean.py` runs the build when the toolchain is on PATH and skips otherwise, and always enforces that no `.lean` file contains `sorry` or `axiom`.

## Files

- `lakefile.lean` -- package/library definition (`L1`).
- `L1.lean` -- root import module.
- `L1/Spelling.lean` -- name mirrors `static/formal/L1/Spelling.v`. Carries a minimal `lexLt`/`shortlexLt` and one ported theorem, `singleton_shortlexLt_iff` (the Lean analogue of Coq's `singleton_ltb_iff`), as a workflow trial: `simp` alone discharges what Coq needed `orb_true_iff`/`andb_true_iff`/`Nat.ltb_lt` bookkeeping for.
