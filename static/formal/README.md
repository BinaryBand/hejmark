# Formal verification

Coq mechanization of the L1 floor (`docs/foundation/L1_TEMP.md`), kept in lockstep with `Himark/core/`. Build with `dune build` from this directory (Coq and dune come from an opam switch; the pytest gate in `tests/infrastructure/test_formal.py` runs the build when the toolchain is on PATH and skips otherwise, but always enforces that no `.v` file contains `Admitted`, `Axiom`, `Parameter`, or any other unproven escape hatch).

## Scope: the membership axis

L1 has two axes. The **membership axis** -- which spellings a universe wears (`Universe.contains`) -- is pure structural set algebra, because collision moves ownership but never membership. That axis is mechanized here, completely and without axioms.

The **order axis** is deferred: entry order and first-appearance enumeration (`Universe.entries`), collision ownership and the least `<value, face>` claim rule, positional value, order types below $\varepsilon_0$, and the claim that shortlex is a well-order of type $\omega$. That last claim also pins the one modeling difference: code points here are all of `nat`, not a finite set, so each length class is already infinite and the type-$\omega$ statement needs the finite code-point set to even hold. A side benefit of `nat` codes is exact successors (`successor [z] = [S z]`, no rollover), which is all the range constructor needs. The `{{{}}, &C}` north-star row (final segment as closure over the literal code-point set `C`) is deferred for the same reason.

## Files (`L1/`)

- `Spelling.v` -- codes, spellings, shortlex as bool with a full order theory (irreflexive, transitive, total, asymmetric), and half-open windows `[lo, hi)`. Key facts: a bounded window is the difference of two final segments, a reversed window is empty, and the range window `[[lo], [S hi])` holds exactly the singletons of the code interval (length dominance).
- `Syntax.v` -- the six constructors as one mutual inductive (`member`/`node`/`factors`), with the member-list and factor-list spines rolled into the inductive so the mutual induction scheme (`syntax_mutind`) is usable and the guard checker never sees a nested list. Union is `napp`; `bindsb` mirrors `_binds`/`_free_amp`.
- `Semantics.v` -- the Prop denotation, faithful to `universe.py`'s membership walk: the accumulator walk (`walk`), member face sets (`spells`), product splits (`fsplit`), closure stages (`stage`, inflationary by construction), and `denotes`. The fold-to-unit boundary uses genuine denotational emptiness (a `forall`), which bool cannot decide.
- `Laws.v` -- the compression laws at membership level: walk decomposition over union, union associativity (structural equality) with idempotence and commutativity on subtraction-free lists, difference, intersection as double subtraction (with an explicit decidability hypothesis instead of classical axioms), bounded ranges as compression `{lo..hi} = {lo.., !{succ hi..}}`, reversed-range emptiness, finite adjacency, unit and empty and the product identities, fold membership with depth flattening, stage monotonicity, and the three bare-`&` no-ops (`{&}` empty, `{a,&} = {a}`, `{a..,!{&}} = {a..}`).
- `Evaluator.v` -- `containsb`, the same algorithm as `_contains` (closure decided at stage `length + 1`, bounded cut search for products, the `addsb` surrogate for the fold unit), with the soundness theorem `containsb_sound : sndb n = true -> containsb n s = true -> denotes n s`. `settledb` mirrors `_settled` and exists to state the deferred fixpoint theorem.
- `NorthStar.v` -- the doc's table as concrete ASTs: positive rows compute through `containsb_sound` by `vm_compute`; negative and emptiness rows are proved at the Prop level, including the `a^n b^n` admission-witness samples (`aabb` in by computation, `aab` out by an even-length stage invariant).

`L1_5/` is a placeholder until the L1.5 draft settles.

## The evaluator's two documented approximations

- **Unsettled closures**: the Python raises `HimarkUnsettledError` where `containsb` answers `false` at the stage bound, so the evaluator under-approximates on unsettled bodies. Exactness on settled bodies is the **deferred fixpoint theorem**: for positive, guarded bodies, `(exists k, stage n k s) <-> stage n (length s + 1) s`. It is the one genuinely hard proof (it also justifies the Python bound and upgrades soundness to exactness on the settled fragment) and is deliberately left as future work rather than an `Admitted`.
- **The fold unit**: denotational emptiness of a fold body is not boolean-decidable (with subtraction it is a language-difference emptiness problem), so `containsb` uses the sound surrogate "no adding member" (`addsb = false`). Divergence: `{{a, !{a}}}` is the unit in the Prop spec and in Python, but `containsb` misses its empty face. No north-star row is affected.

Because a subtraction flips soundness into completeness on its operand, these two gaps shape the soundness side condition `sndb`: closures, folds, and products are fine anywhere positive, but every subtraction operand must sit in the exact fragment (`exactb`: faces, ranges, finals, products of those, nested subtraction -- no fold, no `&`), where the evaluator is proved two-sided (`exact_correct`). Every north-star row satisfies `sndb`.
