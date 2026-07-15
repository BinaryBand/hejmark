"""CI gate: the Lean mechanization under static/lean/ builds and is sorry/axiom-free."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
LEAN = ROOT / "static" / "lean"

# Tokens that would leave a statement unproven or postulated. Lean allows
# `sorry` mid-term (not just line-start like Coq's `Admitted`), so this
# scans anywhere on the line rather than anchoring to the start.
FORBIDDEN = re.compile(r"\bsorry\b|\baxiom\b")


def test_lean_proofs_build() -> None:
    """lake build must succeed, so every module checks end to end.

    Lean and Lake are elan-managed toolchains (like the Coq/dune pair in
    static/formal/), so contributors without the toolchain skip rather than
    fail.
    """
    if shutil.which("lake") is None:
        pytest.skip("Lean toolchain (lake) not on PATH; Lean scaffold not checked")
    result = subprocess.run(
        ["lake", "build"], capture_output=True, text=True, cwd=LEAN, check=False
    )
    assert result.returncode == 0, (
        f"lake build failed (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )


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
