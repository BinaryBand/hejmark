"""CI gate: the Lean mechanization under static/lean/ builds and is sorry/axiom-free."""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
LEAN = ROOT / "static" / "lean"

# Tokens that would leave a statement unproven or postulated. Lean allows
# `sorry` mid-term (not just line-start like Coq's `Admitted`), so this
# scans anywhere on the line rather than anchoring to the start.
FORBIDDEN = re.compile(r"\bsorry\b|\baxiom\b")

# Every headline theorem ported so far. Extend this tuple as later phases port
# more modules; each entry is checked with `#print axioms` below. Only proofs
# that live inside the trusted kernel base belong here: the `native_decide`
# positive north-star rows rest on the extra compiled-reduction axiom
# (`Lean.ofReduceBool`), a different trust basis, so they are deliberately
# excluded from the honesty gate.
HEADLINE_THEOREMS = (
    "L1.singleton_shortlexLt_iff",
    "L1.containsb_sound",
    "L1.anbn_not_aab",
    "L1.cat_only_not_feline",
    "L1.a_minus_a_empty",
    "L1.consonants_not_a",
    "L1.z_to_a_empty",
    "L1.bare_amp_row",
    "L1.guarded_settles",
    "L1.settled_binder_bound",
    "L1.semSettled_of_settledExactb",
    "L1.containsb_exact",
    # North-star completion pass: the final-segment demotion law, the
    # doc-shape fold flattening, the fold-totality unit rows (where the
    # evaluator diverges by design), and the hand-proved non-membership rows.
    "L1.unitClosure_generates",
    "L1.fold_flatten_nested",
    "L1.fold_reversed_is_unit",
    "L1.fold_sub_is_unit",
    "L1.numerals_not_01",
    "L1.unguarded_fill_not_0",
    "L1.abab_not_aba",
    "L1.btrees_not_lparen",
    "L1.z2_not_000",
    # Order axis, phase A: shortlex over a finite alphabet is a well-order of
    # type omega (docs/foundation/L1.md, Spelling order).
    "L1.finShortlex_type_omega0",
    # Order axis, phase B: positional value is mixed radix over a product of
    # finite factors, so the product's order type is the natural product of the
    # factor order types (docs/foundation/L1.md, Positional value).
    "L1.positional_value_type",
    # Order axis, phase C: collision ownership. A spelling is claimed by the
    # least <value, face> address that spells it (value first, face index breaks
    # the tie) and every later claimant drops; the lex order on addresses is a
    # well-order, so ownership is a well-defined unique function of the spelling
    # (docs/foundation/L1.md, Positional value -- the collision rule).
    "L1.collision_settled",
    # Order axis, phase D: bounded transfinitude. The closure-free floor stays
    # below omega^omega, linear closure caps at u * omega, nonlinear closure's
    # squared stages sup to exactly omega^omega, and the full order-type
    # calculus (sums, products, closure limits) never reaches epsilon_0
    # (docs/foundation/L1.md, Bounded transfinitude).
    "L1.floorType_lt_omega0_opow_omega0",
    "L1.linear_closure_lt_omega0_opow_omega0",
    "L1.nonlinear_closure_sup",
    "L1.l1Type_lt_epsilon0",
    # Order axis, phase E: first-appearance enumeration. Stage-major order over
    # omega-many finite stages has type at most omega -- one limit, no
    # continuation past it (docs/foundation/L1.md, Closure).
    "L1.stageMajor_type_le_omega0",
    "L1.stageMajor_type_eq_omega0",
    # Order axis, phase F: collision alone does not decide the type. The
    # {a..}{a..} survivors collapse to omega * (m+1) while the seam row's
    # survivors keep omega * omega (docs/foundation/L1.md, Bounded
    # transfinitude -- the collision examples).
    "L1.cofinite_collision_collapses",
    "L1.seam_collision_survives",
    # Fixpoint on positive bodies: the closure at omega is the least fixpoint
    # of a positive body, and the inflationary and bare stage ladders agree
    # (docs/foundation/L1.md, Fixpoint on settled bodies -- the positive half;
    # the guarded half is L1.guarded_settles above).
    "L1.positive_fixpoint",
    "L1.positive_least",
    "L1.bare_stages_agree",
    # The re-admission test: the universe operand is axiomatic (finitely many
    # entry-wise steps cannot make infinitely many removals), and closure's
    # admission witness {ab, {a}&{b}} denotes exactly a^n b^n, which is not a
    # regular language (docs/foundation/L1.md, the constructors' closing
    # paragraph and "Compression, not capability").
    "L1.operand_needs_infinitely_many_removals",
    "L1.anbn_exact",
    "L1.closure_admission",
    # The entries bridge: order semantics over the real syntax, v1. The
    # ordinal-valued entries enumeration (entriesType) is total on every Node;
    # over a finite code range the spelling order stays within one limit
    # (phase A on real syntax), finite stages keep the first-appearance order
    # within it too (phase E fed by the real stage ladder), and on the
    # demotion row {{{}}, &C} the generated first-appearance order coincides
    # with the spelling order (docs/foundation/L1.md, "Compression, not
    # capability" -- the order-level half of L1.unitClosure_generates above).
    "L1.entriesType_le_omega0",
    "L1.entryLt_type_le_omega0",
    "L1.unitClosure_entriesType",
    "L1.unitClosure_entryLt_type",
    "L1.unitClosure_entryLt_iff",
    "L1.anbn_entriesType",
)

# "Axiom-free" does not port from Coq to Lean literally: every Lean/Mathlib
# proof rests on the trusted kernel base below. The honest gate is that a
# theorem's axiom set is a subset of these, not that it is empty.
TRUSTED_AXIOMS = {"propext", "Classical.choice", "Quot.sound"}


def test_lean_proofs_build() -> None:
    """lake build must succeed, so every module checks end to end.

    Lean and Lake are elan-managed toolchains. A missing toolchain fails this
    test loudly rather than silently skipping it, so contributors must set
    ``HIMARK_SKIP_LEAN=1`` explicitly to opt out.
    """
    if os.environ.get("HIMARK_SKIP_LEAN") == "1":
        pytest.skip("HIMARK_SKIP_LEAN=1 set; Lean scaffold not checked")
    result = subprocess.run(
        ["lake", "build"], capture_output=True, text=True, cwd=LEAN, check=False
    )
    assert result.returncode == 0, (
        f"lake build failed (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )


def test_lean_headline_theorems_are_honestly_axiom_free() -> None:
    """`#print axioms` on every headline theorem must not exceed the trusted kernel base.

    Coq's "Closed under the global context" (zero axioms) is structurally
    unreachable in Lean, since every proof rests on `propext`,
    `Classical.choice`, and `Quot.sound`. This is the Lean-correct
    replacement: each headline theorem's axiom set must be a subset of that
    trusted base, and nothing else.
    """
    if os.environ.get("HIMARK_SKIP_LEAN") == "1":
        pytest.skip("HIMARK_SKIP_LEAN=1 set; Lean scaffold not checked")
    script = "import L1\n" + "\n".join(f"#print axioms {name}" for name in HEADLINE_THEOREMS)
    with tempfile.NamedTemporaryFile("w", suffix=".lean", delete=False) as handle:
        handle.write(script)
        script_path = Path(handle.name)
    try:
        result = subprocess.run(
            ["lake", "env", "lean", str(script_path)],
            capture_output=True,
            text=True,
            cwd=LEAN,
            check=False,
        )
    finally:
        script_path.unlink()
    assert result.returncode == 0, (
        f"#print axioms run failed (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )
    # `#print axioms` emits one record per theorem, but a long axiom list wraps
    # over several lines; each record opens with `'Name' ...`, so regroup the
    # raw output into whole records before matching rather than zipping by line.
    records = re.findall(
        r"'([^']+)' (does not depend on any axioms|depends on axioms: \[([^\]]*)\])",
        result.stdout,
    )
    reported = {name for name, _, _ in records}
    missing = set(HEADLINE_THEOREMS) - reported
    assert not missing, f"no #print axioms output for: {missing}"
    for name, verdict, listed in records:
        if verdict == "does not depend on any axioms":
            continue
        axioms = {item.strip() for item in listed.split(",") if item.strip()}
        extra = axioms - TRUSTED_AXIOMS
        assert not extra, f"{name} depends on untrusted axioms: {extra}"


def test_lean_proofs_are_complete() -> None:
    """No Lean source may contain a `sorry` or a postulated `axiom`.

    Pure text gate: it needs no toolchain and is never skipped, so a proof
    stubbed out with `sorry` fails the suite even where Lean is not installed.
    """
    offenders: list[str] = []
    for path in sorted(LEAN.rglob("*.lean")):
        if ".lake" in path.parts or "build" in path.parts:
            continue
        for number, line in enumerate(path.read_text().splitlines(), start=1):
            if FORBIDDEN.search(line):
                offenders.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()}")
    listing = "\n".join(offenders)
    assert not offenders, f"Lean sources contain unproven escape hatches:\n\n{listing}"
