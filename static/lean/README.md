# Lean 4 scaffold (comparison track)

A parallel toolchain to `static/formal/` (Coq), for comparing workflow and tooling -- not a
second mechanization of L1. Nothing here proves anything about the membership axis yet; that
work stays in Coq until/unless a decision is made to migrate or fork it.

Build with `lake build` from this directory. Lean/Lake come from an `elan`-managed toolchain
(pinned via `lean-toolchain`); the pytest gate in `tests/infrastructure/test_lean.py` runs the
build when the toolchain is on PATH and skips otherwise, and always enforces that no `.lean`
file contains `sorry` or `axiom`.

## Files

- `lakefile.lean` -- package/library definition (`L1`).
- `L1.lean` -- root import module.
- `L1/Spelling.lean` -- placeholder module (name mirrors `static/formal/L1/Spelling.v`) with a
  trivial `rfl` theorem, present only to exercise the build.
