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

# Every headline theorem ported so far. Extend this tuple as Phase 2 ports
# more modules; each entry is checked with `#print axioms` below.
HEADLINE_THEOREMS = ("L1.singleton_shortlexLt_iff",)

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
    for name, line in zip(HEADLINE_THEOREMS, result.stdout.splitlines(), strict=True):
        if "does not depend on any axioms" in line:
            continue
        match = re.search(r"depends on axioms: \[(.*)\]", line)
        assert match, f"unexpected #print axioms output for {name}: {line!r}"
        axioms = {item.strip() for item in match.group(1).split(",") if item.strip()}
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
