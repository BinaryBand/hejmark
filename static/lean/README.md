# Lean 4 mechanization (membership axis)

A full Lean 4 + Mathlib port of the L1 membership axis, mirroring `static/formal/` (Coq) module for module. Phase 2 of `docs/.MIGRATE.md` moved the whole membership floor across; the Coq tree stays alongside as a reference until the Phase 3 purge.

Build with `lake build` from this directory. Lean/Lake come from an `elan`-managed toolchain (pinned via `lean-toolchain`); the pytest gate in `tests/infrastructure/test_lean.py` runs the build when the toolchain is on PATH and skips otherwise, always enforces that no `.lean` file contains `sorry` or `axiom`, and checks every headline theorem's `#print axioms` stays within the trusted kernel base (`propext`, `Classical.choice`, `Quot.sound`).

## Files

Each `L1/*.lean` mirrors the same-named `static/formal/L1/*.v`.

- `lakefile.lean` -- package/library definition (`L1`).
- `L1.lean` -- root import module.
- `L1/Spelling.lean` -- the shortlex spelling order and symbolic `Window`s. Headline: `singleton_shortlexLt_iff` (Lean analogue of Coq's `singleton_ltb_iff`), where `simp` discharges what Coq needed `orb_true_iff`/`andb_true_iff`/`Nat.ltb_lt` bookkeeping for.
- `L1/Syntax.lean` -- the six constructors as one mutual inductive (`Member`/`Node`/`Factors`), with `napp`, binder detection (`bindsb`), and the top-level shape predicates.
- `L1/Semantics.lean` -- the Prop-valued denotation: the mutual `walk`/`spells`/`fsplit`/`stage` block (compiled by well-founded recursion, so unfolding goes through the generated equation lemmas via `simp`, not `rfl`), plus `ndenote`/`denotes` and the monotonicity and stage-accumulation lemmas.
- `L1/Laws.lean` -- the compression laws (union idempotence/commutativity, difference, intersection, range compression, adjacency, fold flattening, bare-`&` no-ops).
- `L1/Evaluator.lean` -- the Bool-valued mutual evaluator (`walkb`/`spellsb`/`fsplitb`/`stageb`, `containsb`) and its soundness headline `containsb_sound`: `containsb` true implies `denotes`.
- `L1/NorthStar.lean` -- the `docs/foundation/L1_TEMP.md` north-star table at the membership level. Positive rows compute through `containsb_sound` and `native_decide` (the Lean analogue of Coq's `vm_compute`); negative and emptiness rows are proved at the Prop level, mostly as corollaries of `Laws`.

## Trust note

"Axiom-free" does not port from Coq literally: every Lean/Mathlib proof rests on the trusted kernel base above, so the honest gate is that a headline theorem's axiom set is a subset of it. The `native_decide` positive rows additionally rest on the compiled-reduction axiom (`Lean.ofReduceBool`), a distinct trust basis, and so are kept out of the honesty gate; the sound Prop-level rows and `containsb_sound` itself carry only the trusted base.
